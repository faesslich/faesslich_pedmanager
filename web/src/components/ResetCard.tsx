import { useT } from "../hooks/useT";

interface ResetCardProps {
    onClick: () => void;
}

export function ResetCard({ onClick }: ResetCardProps) {
    const t = useT();
    return (
        <div
            className="group relative rounded-xl border-2 border-dashed border-gray-700 hover:border-red-500/50 bg-gray-900/40 overflow-hidden flex flex-col items-center justify-center cursor-pointer transition-all duration-300 min-h-[200px]"
            onClick={onClick}
        >
            <svg className="w-10 h-10 text-gray-600 group-hover:text-red-400 transition" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                />
            </svg>
            <span className="mt-2 text-sm text-gray-500 group-hover:text-red-400 font-medium transition">
                {t("nui_reset_default")}
            </span>
        </div>
    );
}

