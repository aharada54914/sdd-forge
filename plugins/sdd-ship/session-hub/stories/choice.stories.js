import { choiceButton } from '../components.mjs';
export default { title:'Hub/Choice', render:args => choiceButton(args), args:{label:'この選択肢にする', variant:'primary', selected:false, disabled:false} };
export const Variants = { render:args => { const root = document.createElement('div'); root.className = 'actions'; root.append(choiceButton({...args,variant:'primary'}), choiceButton({...args,variant:'secondary'})); return root; } };
export const Selected = { args:{selected:true} };
export const Received = { args:{selected:true,disabled:true} };
