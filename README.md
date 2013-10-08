c't-WORDCLOCK
=============

Schaltplan, Layouts, Stückliste, Firmware für WordClock-Plojekt aus c't-Hacks 3/2013

Enthalten sind zwei Firmware-Versionen:

WordClock_Pong_mega8.hex: lauffähig auf Franzis/Conrad "Pong"-Spiel, mit Wordclock_110.pdf

WordClock_mega8.hex: für c't-Wordclock-Platine "WordClock-Strip" (Segor-Bausatz), mit Wordclock_144.pdf

Der Download gestaltet sich einfacher, wenn Sie dieses komplette Repository als ZIP downloaden (Button rechts) 
und die HEX-Files extrahieren. Ansonsten wird die HEX-Datei als Text angezeigt, der erst in einen 
Texteditor geladen und neu abgespeichert werden muss.

Sie benötigen zum Kompilieren bei eigenen Änderungen den kostenlosen Compiler 
AVRCo Pascal Mega8 von E-Lab (http://www.e-lab.de). Ansonsten reicht ein AVR-Programmer.

Layout und Schaltpläne zum Selbstanfertigen der Platinen ebenfalls beiliegend. Wir empfehlen,
auf den ab Ende August 2013 verfügbaren Bausatz "c't-WordClock" von Segor (http://www.segor.de) zurückzugreifen.

Fertig geschnittene Folien für die Frontplatte erhalten Sie zum Beispiel bei http://www.plottflott.de (40x40-Version).

Wichtige Hinweise
=================

Im Unterschied zur Darstellung im Artikel wird der Bausatz unbestückt und unprogrammiert geliefert. 
Sie benötigen deshalb neben SMD-Lötkenntnissen auch einen Programmer für Atmel AVR Prozessoren.

Die im Heft abgedruckte Textanzeige war fehlerhaft und kann bestimmte Phrasen nicht anzeigen. 
Bitte verwenden Sie die Vorlage "Wordclock_144.pdf".

Als Verbesserung enthält der Komplettbausatz einen 12 LED-Streifen mit weißen Osram PointLEDs.
Der Streifen wird nun mit MicroMatch-Steckverbindern an die WordClock-Strip-Platine angeschlossen, 
was die Verdrahtung stark vereinfacht und einen besonders flachen Aufbau ermöglicht.

Auf jedem LED-Streifen befindet sich ein Lötpad, das mit dem entsprechenden Anschluss "LED MATRIX ANODES" 
(Einzeladern von PL1 und PL2, je eine Ader zu jedem Strip) zu verbinden ist. 
Beachten Sie die Kennzeichnung BTM ROW (unterste Reihe) bis TOP ROW (oberste Reihe) sowie die Polarität der PointLEDs:
Anode (+) ist rückseitig mit einem kleinen Oval in Form eines Schlüssellochs gekennzeichnet 
(ggf. Lupe verwenden, siehe auch beiliegendes Bild "pointled.png").

Die Micromatch-Stecker von Strips und Uhrenplatine fluchten nur, 
wenn man die Platine an den Rand eines 40-cm-Bilderrahmens einsetzt. 
Sollte das Flachbandkabel etwas zu "störrisch" sein, kann man es nach 
Anpressen der Micromatch-Stecker (z.B. in einem Mini-Schraubstock, 
Nase = Pin 1 = rote Ader) in 2x6 Adern aufschneiden.

-cm
