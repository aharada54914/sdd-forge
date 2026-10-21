"""Trusted post-output scorer boundary. Candidate public tools never mount these evaluator inputs."""
import argparse,json,pathlib,sys
from isolation import command,execute
ROOT=pathlib.Path(__file__).resolve().parent
BASE=ROOT.parent
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('case',choices=['harbor','orchard','meadow','willow','cedar','maple']);p.add_argument('project',type=pathlib.Path);p.add_argument('--answer',type=pathlib.Path);p.add_argument('--reviewed-harbor',action='store_true',help='Root completed semantic review of submitted Harbor Python before its execution.');a=p.parse_args()
    if a.case=='harbor' and not a.reviewed_harbor:p.error('Root semantic review is required before Harbor source execution; then supply --reviewed-harbor.')
    if a.case!='harbor' and a.answer is None:p.error('--answer is required for text-output cases')
    argv=['/checker/score.py',a.case,'/project']+(['--answer','/answer.txt'] if a.answer else [])
    result=execute(command(a.project,argv,checker={'scorer':BASE/'score.py','fixtures':BASE/'inputs','answer':a.answer}),300,environment={'PATH':'/usr/bin:/bin','LANG':'C.UTF-8'})
    print(result['output'],end='' if result['output'].endswith('\n') else '\n');sys.exit(0 if result['success'] else 1)
