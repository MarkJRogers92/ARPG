# Independent integration review

Reviewer: the existing `specialist_review` agent, GPT-6.1-sol, read-only code and geometry review. Review covered the six-model adapter/batching implementation, movement correction, upstream rebase overlap, and the later approved Ferryman/Collector pair. It did not perform GPU gameplay QA; rendered evidence was inspected separately by the implementing agent.

The substantive signature finding was that six split vertices in a low Collector chain link entered the shared foot deformation mask. At full stride their Z displacement could be about 6.45 cm on an 8.3 cm deep link. A Collector-only `leg_width = 0.14` keeps the boots inside the mask and every low emissive chain vertex outside it. The regression test failed on the previous mask and passed after the correction. Review independently rechecked the delivered GLB: zero of 192 low emissive chain vertices now enter the mask, compared with six previously.

Review found no other remaining issues in the inspected paths: both surfaces receive the appropriate shader, imported glow is not doubled, the original fallback remains available, swarm assignment survives removal/recycling, gameplay RNG and stats are preserved, and Ferryman encounter orientation, lighting and mechanics stay in their original call paths. The fail-closed separate-save preview launcher was also checked.
