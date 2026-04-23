import { useSyncExternalStore } from "react";
import { t as translate, subscribeLocale, getLocaleVersion } from "../lib/locale";

export function useT() {
    useSyncExternalStore(
        subscribeLocale,
        getLocaleVersion,
        () => 0,
    );
    return translate;
}

