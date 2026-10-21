"""Fixture-only dynamic handlers and event accounting; no model/process launch."""
import hashlib
import json
import time

MAX_CALLS = 24
MAX_SECONDS = 300
MAX_FILE_BYTES = 131072
TOOL_ITEM_TYPES = {'commandExecution','fileChange','mcpToolCall','dynamicToolCall','collabAgentToolCall','webSearch','imageView','sleep','imageGeneration'}

def specs(writable):
    tools = [dict(type='function',name='Read',description='Read an existing project file. Paths are exact relative project filenames.',inputSchema={'type':'object','properties':{'path':{'type':'string'}},'required':['path'],'additionalProperties':False})]
    if writable:
        tools += [dict(type='function',name='Edit',description='Replace selector.py with complete UTF-8 source. No other file is editable.',inputSchema={'type':'object','properties':{'path':{'type':'string'},'content':{'type':'string'}},'required':['path','content'],'additionalProperties':False}),dict(type='function',name='RunPublicChecks',description='Run the existing project public test only; no command arguments are accepted.',inputSchema={'type':'object','properties':{},'additionalProperties':False})]
    return tools

class FixtureTools:
    def __init__(self, files, *, writable=False, clock=time.monotonic, public_checks=None):
        # Only explicitly supplied candidate bytes. No evaluator root/path or source repository reference is stored.
        if not files or any(not isinstance(k,str) or k.startswith('/') or '..' in k.split('/') or '\\' in k for k in files):
            raise ValueError('invalid project file set')
        if any(not isinstance(v,str) or len(v.encode())>MAX_FILE_BYTES for v in files.values()): raise ValueError('invalid file bytes')
        self.files=dict(files); self.initial=dict(files); self.writable=writable
        self.clock=clock; self.started=clock(); self.public_checks=public_checks
        self.calls=0; self.failed=[]; self.log=[]

    def dispatch(self, tool, arguments):
        self.calls += 1
        if self.clock()-self.started>MAX_SECONDS:
            self.failed.append('timeout'); return self.response(False,'Wall budget exceeded.')
        if self.calls>MAX_CALLS:
            self.failed.append('tool-budget-exceeded'); return self.response(False,'Tool budget exceeded.')
        self.log.append({'tool':tool,'arguments_sha256':hashlib.sha256(json.dumps(arguments,sort_keys=True).encode()).hexdigest()})
        if not isinstance(arguments,dict): return self.response(False,'Arguments must be an object.')
        if tool=='Read' and set(arguments)=={'path'}:
            path=arguments['path']
            if isinstance(path,str) and path in self.files: return self.response(True,self.files[path])
        elif tool=='Edit' and self.writable and set(arguments)=={'path','content'}:
            content=arguments['content']
            if arguments['path']=='selector.py' and isinstance(content,str) and len(content.encode())<=MAX_FILE_BYTES:
                self.files['selector.py']=content; return self.response(True,'Updated selector.py.')
        elif tool=='RunPublicChecks' and self.writable and not arguments:
            if self.public_checks is None: return self.response(False,'Public test executor is not configured.')
            try:
                result=self.public_checks(dict(self.files),max(0,MAX_SECONDS-(self.clock()-self.started)))
                if not isinstance(result,dict) or set(result)!={'success','output'} or type(result['success']) is not bool or not isinstance(result['output'],str):raise ValueError('invalid executor output')
                return self.response(result['success'],result['output'][:16384])
            except Exception: return self.response(False,'Public check execution failed.')
        return self.response(False,'Tool or arguments are outside this project interface.')

    @staticmethod
    def response(success, text): return {'success':success,'contentItems':[{'type':'inputText','text':text}]}

    def artifacts(self):
        changed={k for k in self.initial.keys()|self.files.keys() if self.initial.get(k)!=self.files.get(k)}
        if not changed <= ({'selector.py'} if self.writable else set()): raise ValueError('unauthorized artifact mutation')
        return dict(self.files)

class EventController:
    """Public item/tool/call responder; returns protocol replies, never sends network requests."""
    def __init__(self, tools, thread_id, turn_id):
        self.tools=tools;self.thread_id=thread_id;self.turn_id=turn_id
        self.seen_items=set();self.served_calls=set();self.dynamic_items=set();self.builtin_count=0
        self.failures=[];self.reroutes=[];self.final=None

    def handle(self,message):
        method=message.get('method');p=message.get('params',{})
        if p.get('threadId')!=self.thread_id or (p.get('turnId') is not None and p.get('turnId')!=self.turn_id):
            if method=='item/tool/call' and 'id' in message:
                return {'id':message['id'],'result':FixtureTools.response(False,'Unrelated thread/turn.')}
            return None
        if method=='item/tool/call' and 'id' in message:
            call=p.get('callId')
            if not isinstance(call,str) or call in self.served_calls:
                self.failures.append('duplicate-or-invalid-call');result=FixtureTools.response(False,'Duplicate or invalid call.')
            elif p.get('namespace') is not None:
                self.served_calls.add(call);self.tools.calls+=1;self.failures.append('unexpected-tool-namespace');result=FixtureTools.response(False,'Namespace not supported.')
            else:
                self.served_calls.add(call);pass
                if max(self.tools.calls+1,len(self.dynamic_items))+self.builtin_count>MAX_CALLS:
                    self.tools.calls+=1;self.tools.failed.append('tool-budget-exceeded')
                    result=FixtureTools.response(False,'Tool budget exceeded.')
                else:
                    result=self.tools.dispatch(p.get('tool'),p.get('arguments'))
            return {'id':message['id'],'result':result}
        if method=='item/started':
            item=p.get('item',{}); ident=item.get('id');kind=item.get('type')
            if kind in TOOL_ITEM_TYPES and ident not in self.seen_items:
                self.seen_items.add(ident)
                if kind=='dynamicToolCall':
                    self.dynamic_items.add(ident)
                else:
                    self.builtin_count+=1;self.failures.append('unexpected-builtin-tool:'+kind)
        if method=='model/rerouted': self.reroutes.append(dict(p))
        if method=='item/completed' and p.get('item',{}).get('type')=='agentMessage':self.final=p['item']['text']
        if self.observed_calls>MAX_CALLS:self.failures.append('tool-budget-exceeded')
        if self.tools.clock()-self.tools.started>MAX_SECONDS:self.failures.append('timeout')
        return None

    @property
    def observed_calls(self):return max(self.tools.calls,len(self.dynamic_items))+self.builtin_count

    def summary(self):
        failures=set(self.failures+self.tools.failed)
        if self.observed_calls>MAX_CALLS:failures.add('tool-budget-exceeded')
        if self.tools.clock()-self.tools.started>MAX_SECONDS:failures.add('timeout')
        return {'observed_tool_calls':self.observed_calls,'dynamic_requests':self.tools.calls,'dynamic_item_count':len(self.dynamic_items),'builtin_tool_items':self.builtin_count,'failures':sorted(failures),'actual_id':None,'proof':'unverified','reroutes':self.reroutes,'os_isolation':'not established by this handler'}
