export class LocalStorageService {
  get<T>(name: string): T | undefined {
    const json = window.localStorage.getItem(this.getKeyName(name));
    if (!json) return;

    try {
      return JSON.parse(json);
    } catch {
      return;
    }
  }

  set<T>(name: string, value: T | undefined) {
    const json = value ? JSON.stringify(value) : "";
    window.localStorage.setItem(this.getKeyName(name), json);
  }

  private getKeyName(name: string): string {
    return `bb_${name}`;
  }
}
