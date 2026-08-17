import { parseCombatLog } from './LocalCombatLogParser';

self.onmessage = (message: MessageEvent<{ text: string; id: string }>) => {
  try {
    self.postMessage({
      type: 'result',
      result: parseCombatLog(message.data.text, message.data.id),
    });
  } catch (error) {
    self.postMessage({
      type: 'error',
      message: error instanceof Error ? error.message : 'Unable to parse combat log',
    });
  }
};
