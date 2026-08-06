import os
import re

d = 'app/routers'
for f in os.listdir(d):
    if not f.endswith('.py'): continue
    path = os.path.join(d, f)
    with open(path, 'r', encoding='utf-8') as file:
        c = file.read()
    
    c = re.sub(r'(\w+_id):\s*uuid\.UUID', r'\1: str', c)
    
    with open(path, 'w', encoding='utf-8') as file:
        file.write(c)
print('Done!')
