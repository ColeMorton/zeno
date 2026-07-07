// Make index.html ASCII-only so it renders correctly regardless of served charset.
// HTML markup -> &#x..; entities ; JS (inside <script>) -> \u escapes. Idempotent.
import fs from 'fs';
const f='index.html'; let h=fs.readFileSync(f,'utf8');
const open=h.indexOf('<script>')+'<script>'.length;
const close=h.lastIndexOf('</script>');
const entity=s=>[...s].map(c=>{const cp=c.codePointAt(0);return cp>127?`&#x${cp.toString(16).toUpperCase()};`:c;}).join('');
const jsesc=s=>[...s].map(c=>{const cp=c.codePointAt(0);return cp>127?(cp<=0xFFFF?`\\u${cp.toString(16).toUpperCase().padStart(4,'0')}`:`\\u{${cp.toString(16).toUpperCase()}}`):c;}).join('');
h=entity(h.slice(0,open))+jsesc(h.slice(open,close))+entity(h.slice(close));
fs.writeFileSync(f,h);
const left=[...h].filter(c=>c.codePointAt(0)>127).length;
console.log('remaining non-ASCII:',left);
