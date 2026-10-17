from puzzle2 import Puzzle, describe
import sys
rooms=[0,1,2,2,2,2,1]
def make(drop3=False):
    links=[{'kind':'open'},
           ({'kind':'open'} if drop3 else {'kind':'door','trig':[3,2],'all':True,'inv':True}),
           {'kind':'door','trig':[5,4],'all':True,'inv':True},
           {'kind':'door','trig':[5,2],'all':False,'inv':False},
           {'kind':'door','trig':[4],'all':True,'inv':False},
           {'kind':'door','trig':[1,2],'all':True,'inv':True}]
    plates={1:{'room':1,'th':1},2:{'room':4,'th':1},4:{'room':2,'th':2},5:{'room':0,'th':2}}
    if not drop3: plates[3]={'room':0,'th':1,'latch':True}
    return Puzzle(rooms,links,plates,[2,0,5],{},())
for d in (False, True):
    p=make(d); r=p.analyze(400000)
    print('без защёлки' if d else 'с защёлкой', r['len'], r['states'], r['dead'], f"{r['dead']/r['states']:.0%}")
    if d: 
        for s in r['path']: print('   ', s)
