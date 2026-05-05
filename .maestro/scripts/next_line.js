/* global LINES, INDEX, output */
var lines = JSON.parse(LINES);
var index = parseInt(INDEX, 10);
output.currentLine = lines[index];
output.lineIndex = String(index + 1);
output.lines = LINES;
output.lineCount = String(lines.length);
