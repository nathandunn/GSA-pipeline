This is a placeholder directory that mirrors
the directory structure required when the
markup pipeline is run at Caltech.

It must exist in advance; it is not created.

More sensibly and cleanly, it should probably
be placed in a top-level "input" directory:

  input/known_entities

It is populated by:

  ./scripts/01_01gene.pl           > known_entities/Gene
  ./scripts/01_02transgene.pl      > known_entities/Transgene
  ./scripts/01downloadModEntities.pl  > known_entities/Clone, etc

Todd Harris