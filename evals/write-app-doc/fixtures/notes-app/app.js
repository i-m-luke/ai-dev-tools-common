const NOTES_KEY = 'notes';
const SETTINGS_KEY = 'notes-settings';

let notes = JSON.parse(localStorage.getItem(NOTES_KEY) ?? '[]');
let selectedId = null;
const settings = JSON.parse(localStorage.getItem(SETTINGS_KEY) ?? '{"autosave":false}');

const list = document.getElementById('note-list');
const editor = document.getElementById('editor');
const settingsDialog = document.getElementById('settings-dialog');
const autosaveOption = document.getElementById('autosave-option');

function persistNotes() {
  localStorage.setItem(NOTES_KEY, JSON.stringify(notes));
}

function titleOf(note) {
  return note.text.split('\n')[0] || '(empty note)';
}

function render() {
  list.innerHTML = '';
  for (const note of notes) {
    const item = document.createElement('li');
    item.textContent = titleOf(note);
    item.classList.toggle('selected', note.id === selectedId);
    item.addEventListener('click', () => selectNote(note.id));
    list.appendChild(item);
  }
}

function selectNote(id) {
  selectedId = id;
  editor.value = notes.find(n => n.id === id)?.text ?? '';
  render();
}

function confirmDelete() {
  return confirm('Delete this note?');
}

function exportCsv() {
  const rows = notes.map(n => [n.id, new Date(n.modified).toISOString(), JSON.stringify(n.text)].join(','));
  const csv = ['id,modified,text', ...rows].join('\n');
  const link = document.createElement('a');
  link.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
  link.download = 'notes.csv';
  link.click();
}

document.getElementById('new-btn').addEventListener('click', () => {
  const note = { id: Date.now(), text: '', modified: Date.now() };
  notes.unshift(note);
  persistNotes();
  selectNote(note.id);
});

document.getElementById('save-btn').addEventListener('click', exportCsv);

document.getElementById('delete-btn').addEventListener('click', () => {
  if (selectedId === null) return;
  notes = notes.filter(n => n.id !== selectedId);
  selectedId = null;
  editor.value = '';
  persistNotes();
  render();
});

document.getElementById('sort-btn').addEventListener('click', () => {
  notes.sort((a, b) => b.modified - a.modified);
  render();
});

document.getElementById('settings-btn').addEventListener('click', () => {
  autosaveOption.checked = settings.autosave;
  settingsDialog.showModal();
});

autosaveOption.addEventListener('change', () => {
  settings.autosave = autosaveOption.checked;
  localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
});

document.getElementById('settings-close').addEventListener('click', () => settingsDialog.close());

editor.addEventListener('input', () => {
  const note = notes.find(n => n.id === selectedId);
  if (!note) return;
  note.text = editor.value;
  note.modified = Date.now();
  if (settings.autosave) persistNotes();
  render();
});

render();
