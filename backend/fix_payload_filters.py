import os
import re

d = 'app/routers'
for f in os.listdir(d):
    if not f.endswith('.py'): continue
    path = os.path.join(d, f)
    with open(path, 'r', encoding='utf-8') as file:
        c = file.read()
    
    # We will cast payload variables to string inside filters.
    # E.g., filter(models.Question.template_id == payload.template_id) -> filter(models.Question.template_id == str(payload.template_id))
    c = re.sub(r'== payload\.([a-z_]+)', r'== str(payload.\1)', c)
    
    with open(path, 'w', encoding='utf-8') as file:
        file.write(c)
print('Done!')
