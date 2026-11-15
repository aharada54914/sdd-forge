export const COMPONENT_VERSION = '1';
export const STORY_ID = 'hub-choice--variants';
export function choiceButton({ label, variant = 'primary', selected = false, disabled = false, onSelect = () => {} }) {
  const button = document.createElement('button');
  button.type = 'button'; button.textContent = label;
  button.className = 'hub-choice ' + (variant === 'secondary' ? 'secondary' : 'primary');
  button.setAttribute('aria-pressed', String(selected)); button.disabled = disabled;
  button.addEventListener('click', onSelect);
  return button;
}
