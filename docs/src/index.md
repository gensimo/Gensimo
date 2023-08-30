GENSIMO
=======

**GENeric Social Insurance MOdelling**, GENSIMO for short, is a modelling framework written in Julia for the representation, analysis and simulation of social insurance systems.

### Modelling Social Insurance Systems ###

The GENSIMO framework models the dynamics of clients interacting with a particular insurance scheme. Over time, a client may receive several _services_ -- typically compensation payments -- which are tallied up administratively as part of the client's _claim_. Some services are granted without much scrutiny, whereas some _service requests_ involve a deliberation between the insurer and the client. In some cases, external parties such as lawyers or medical professionals may be engaged in these deliberations.

These dynamics are represented in the GENSIMO framework as a succession of client _states_ interspersed by _deliberative processes_, where each successive state is the outcome of such a process. This leads to a picture like in Figure 1. With an appropriate notion of 'state', the client-scheme dynamics can then be formalised as a Markov Decision Process (MDP, see e.g. <https://en.wikipedia.org/wiki/Markov_decision_process>). An MDP has a state space and an action space -- containing all possible states and actions, respectively. The actions in GENSIMO correspond to models of a deliberative process and, in principle, a completely different model can be used for each action.

![client pathways](images/pathways-gen.png)
Figure 1. _Client pathway from the GENSIMO perspective._

Which state is followed by which action is dictated by the _policy_. Typically MDPs are used to find some form of _optimal_ policy, for example, using Dynamic Programming or Reinforcement Learning algorithms. Though this could be done in the GENSIMO framework, it is not the default approach. Rather, the policy represents the settings of the scheme -- that is, the settings of the modelled version of the scheme.


