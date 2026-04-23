interface TabButtonProps {
    active: boolean;
    onClick: () => void;
    label: string;
    count: number;
}

export function TabButton({ active, onClick, label, count }: TabButtonProps) {
    return (
        <button
            onClick={onClick}
            className={`px-4 py-2 text-sm font-medium rounded-md transition-all duration-200 ${
                active
                    ? "bg-primary-600 text-white shadow-lg shadow-primary-600/20"
                    : "text-gray-400 hover:text-white hover:bg-gray-700/50"
            }`}
        >
            {label}
            <span
                className={`ml-2 px-1.5 py-0.5 text-xs rounded-full ${
                    active ? "bg-primary-500/30 text-primary-200" : "bg-gray-700 text-gray-400"
                }`}
            >
                {count}
            </span>
        </button>
    );
}

