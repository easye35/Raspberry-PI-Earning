let theme = 'dark';

function toggleTheme() {
  theme = theme === 'dark' ? 'light' : 'dark';
  document.body.className = theme;
}
