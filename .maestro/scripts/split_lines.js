/* global VALUE, output */
var lines = VALUE.split('\n');
if (lines[lines.length - 1] === '') lines.pop();
output.lines = JSON.stringify(lines);
output.lineCount = lines.length;
output.lineIndex = '0';
