GENSIMO
=======

**GENeric Social Insurance MOdelling**

GENSIMO is a modelling framework written in Julia for the representation, analysis and simulation of social insurance systems.

### Modelling Social Insurance Systems ###

The GENSIMO framework models the dynamics of clients interacting with a particular insurance scheme. Over time, a client may receive several *services* -- typically compensation payments -- which are tallied up administratively as part of the client's *claim*. Some services are granted without much scrutiny, whereas some *service requests* involve a deliberation between the insurer and the client. In some cases, external parties such as lawyers or medical professionals may be engaged in these deliberations.

These dynamics are represented in the GENSIMO framework as a succession of client *states* interspersed by *deliberative processes*, where each successive state is the outcome of such a process. 





