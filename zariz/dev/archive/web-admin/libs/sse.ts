export function subscribe(url: string, onData: (msg: any) => void) {
  const es = new EventSource(url);
  es.onmessage = (e) => {
    try {
      onData(JSON.parse(e.data));
    } catch {
      // ignore invalid payloads
    }
  };
  return () => es.close();
}

