"""Unchanged frozen scorer with v5 skill-only readonly fixture baselines."""
import argparse,pathlib,sys
ROOT=pathlib.Path(__file__).resolve().parent
BASE=ROOT.parent
sys.path.insert(0,str(BASE/'executor-preparation-v4'))
from isolation import command,execute
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('case',choices=['cedar','maple']);p.add_argument('project',type=pathlib.Path);p.add_argument('--answer',required=True,type=pathlib.Path);a=p.parse_args()
    argv=command(a.project,['/checker/score.py',a.case,'/project','--answer','/answer.txt'],checker={'scorer':BASE/'score.py','fixtures':ROOT/'inputs','answer':a.answer})
    result=execute(argv,300,environment={'PATH':'/usr/bin:/bin','LANG':'C.UTF-8'})
    print(result['output'],end='' if result['output'].endswith('\n') else '\n');sys.exit(0 if result['success'] else 1)
