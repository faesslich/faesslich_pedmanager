// ============================================================================
// Locale store for the NUI — receives translation strings from Lua at runtime.
// ============================================================================

let localeStrings: Record<string, string> = {};
let currentLanguage = "en";
let version = 0;
const listeners = new Set<() => void>();

export function setLocaleStrings(strings: Record<string, string>, language?: string): void {
    localeStrings = strings ?? {};
    if (language) currentLanguage = language;
    version++;
    listeners.forEach((l) => l());
}

export function getLanguage(): string {
    return currentLanguage;
}

/** Monotonically increasing version — bumped on every `setLocaleStrings` call. */
export function getLocaleVersion(): number {
    return version;
}

export function subscribeLocale(cb: () => void): () => void {
    listeners.add(cb);
    return () => {
        listeners.delete(cb);
    };
}

export function t(key: string, ...args: (string | number)[]): string {
    let str = localeStrings[key] ?? key;
    if (args.length === 0) return str;

    let argIndex = 0;
    str = str.replace(/%([sd%])/g, (match, type: string) => {
        if (type === "%") return "%";
        if (argIndex >= args.length) return match;
        const val = args[argIndex++];
        if (type === "d") return String(Math.floor(Number(val)));
        return String(val);
    });
    return str;
}

