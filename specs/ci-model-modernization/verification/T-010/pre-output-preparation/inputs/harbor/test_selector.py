from selector import select
c = [{"id":"spruce","tier":1,"roles":["build"]},{"id":"elm","tier":2,"roles":["build"]}]
assert select({"role":"build","floor":1},c,{"fresh":True,"available":["spruce","elm"]}) == "spruce"
