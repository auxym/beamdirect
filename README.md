# beamdirect

Beamdirect is a hobby project with the goal of being a simple two-dimensional GUI beam and shaft analysis software tool.
It is inspired by a commercial software I had used in the past named "Orand Systems Beam2D" which is not available anymore.
In addition to beam analysis features (displacements, stresses, shear force and bending moment diagrams), it was planned to 
add basic rotordynamics features such as Campbell diagrams for rotating machinery shaft analysis.

## Status

The current status of beamdirect is:

* A basic, proof-of-concept solver engine that accepts input as JSON5 and produces in-memory output.
* Concentrated force loading and arbitrary displacement boundary conditions are supported.
* The engine was validated against some example problems (see tests) and appears to produce correct displacement results.
* There is no user interface (GUI or CLI), the only running code currently are the tests.

Though I am interested in pursuing development of this tool "some day", my current time availability makes it so no further
development is planned for the immediate future.

## Theory

The beamdirect "solver engine" is mostly based on the direct stiffness method, as described in the excellent textbook
[Matrix Structural Analysis](http://www.mastan2.com/textbook.html) by William McGuire, Richard H. Gallagher and
Ronald D. Zieman.

Some inspiration was also taken around matrix/DOF organization and BC application from the
[NASTRAN-95](https://github.com/nasa/NASTRAN-95) source code and associated documentation.
