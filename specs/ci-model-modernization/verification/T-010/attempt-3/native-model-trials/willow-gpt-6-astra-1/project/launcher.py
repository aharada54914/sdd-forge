from selector import choose
from records import save

def launch(policy, agent, host):
    selected = choose(policy)
    configured = agent.get("model", selected)
    response = host.start(model=configured)
    return save(selected, configured, response)
