from spark_puzzle import SparkPuzzle
links=[('S','A',None),('A','K1z',None),('K1z','R2a','!W1'),('R2a','R2b',None),('R2b','BR','BRG'),('BR','R3a','BRG'),
       ('R3a','D',None),('D','C',None),('R2b','LC','!BRG'),('R3a','LC','!BRG'),('LC','LCw',None),('LCw','X','!W2')]
p=SparkPuzzle(places=None, links=links,
  net={'G':('A','J2','K1'),'J2':('L','ground','J3'),'J3':('D','KB','J4'),'J4':('C','ground','K2')},
  kegs={'K1':['W1'],'KB':['BRG'],'K2':['W2']}, plates={'A':1,'D':1,'C':2}, levers={'L':'R2a'},
  crates=['R2a'], start='S', goal='X', blast={'K1':{'A','K1z'},'KB':{'R2b','BR'},'K2':{'LCw'}},
  drops=[('R2b','LC'),('R3a','LC')])
r=p.solve()
print('ходов', len(r['path']) if r['path'] else None, 'состояний', r['states'], 'ловушек', r.get('dead'))
for s in r['path'] or []: print('  ', s)
