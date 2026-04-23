import type { ButtonColor } from "../types";

const COLOR_MAP: Record<ButtonColor, string> = {
    primary: "bg-primary-600/80 hover:bg-primary-500 text-white",
    green: "bg-emerald-600/80 hover:bg-emerald-500 text-white",
    red: "bg-red-600/80 hover:bg-red-500 text-white",
    yellow: "bg-yellow-600/80 hover:bg-yellow-500 text-white",
    orange: "bg-orange-500/80 hover:bg-orange-400 text-white",
};

interface ActionBtnProps {
    icon: string;
    title: string;
    color: ButtonColor;
    onClick: () => void;
}

export function ActionBtn({ icon, title, color, onClick }: ActionBtnProps) {
    return (
        <button
            onClick={(e) => {
                e.stopPropagation();
                onClick();
            }}
            title={title}
            className={`flex-1 py-1.5 text-xs font-medium rounded-lg transition-all duration-200 ${COLOR_MAP[color]}`}
        >
            {icon}
        </button>
    );
}

