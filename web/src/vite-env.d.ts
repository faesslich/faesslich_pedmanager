/// <reference types="vite/client" />
interface Window {
    invokeNative?: (native: string, ...args: unknown[]) => void;
    GetParentResourceName?: () => string;
}

