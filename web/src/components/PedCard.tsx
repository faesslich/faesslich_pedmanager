import type { ReactNode } from "react";
import { useT } from "../hooks/useT";

interface PedCardProps {
    model: string;
    image: string;
    isDefault?: boolean;
    owned?: boolean;
    custom?: boolean;
    actions: ReactNode;
}

export function PedCard({ model, image, isDefault, owned, custom, actions }: PedCardProps) {
    const t = useT();
    const borderClass = isDefault
        ? "border-yellow-500/50 ring-1 ring-yellow-500/20"
        : owned
            ? "border-primary-500/30"
            : "border-gray-700/60 hover:border-gray-600";

    return (
        <div
            className={`group relative rounded-xl border overflow-hidden bg-gray-900/60 hover:bg-gray-800/60 transition-all duration-300 hover:scale-[1.02] hover:shadow-xl hover:shadow-primary-900/10 ${borderClass}`}
        >
            <div className="aspect-square bg-gray-800/50 p-4 overflow-hidden relative">
                <img
                    src={image}
                    alt={model}
                    className="w-full h-full object-contain transition-transform duration-500 group-hover:scale-110"
                    loading="lazy"
                    onError={(e) => {
                        (e.target as HTMLImageElement).style.display = "none";
                    }}
                />

                <div className="absolute top-2 left-2 flex gap-1">
                    {isDefault && (
                        <span className="px-2 py-0.5 text-[10px] font-bold bg-yellow-500/90 text-yellow-950 rounded-full uppercase tracking-wider">
                            {t("nui_badge_default")}
                        </span>
                    )}
                    {owned && !isDefault && (
                        <span className="px-2 py-0.5 text-[10px] font-bold bg-primary-500/90 text-white rounded-full uppercase tracking-wider">
                            {t("nui_badge_owned")}
                        </span>
                    )}
                    {custom && (
                        <span className="px-2 py-0.5 text-[10px] font-bold bg-purple-500/90 text-white rounded-full uppercase tracking-wider">
                            {t("nui_badge_custom")}
                        </span>
                    )}
                </div>
            </div>

            <div className="p-3">
                <p className="text-xs text-gray-300 font-mono truncate mb-2" title={model}>
                    {model}
                </p>
                {actions}
            </div>
        </div>
    );
}

