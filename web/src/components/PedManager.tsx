import { useState, useEffect, useMemo, useCallback } from "react";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { useT } from "../hooks/useT";
import { setLocaleStrings } from "../lib/locale";
import { nuiCallback } from "../util/nuicallback";
import { Tab, CategoryFilter } from "../types";
import type { MyPed, AvailablePed, OpenPedManagerData, PedCategory } from "../types";
import { TabButton } from "./TabButton";
import { PedCard } from "./PedCard";
import { ActionBtn } from "./ActionBtn";
import { EmptyState } from "./EmptyState";
import { ResetCard } from "./ResetCard";

const IS_BROWSER = !window.invokeNative;

function getCategory(model: string, fallback?: PedCategory): PedCategory {
    if (fallback) return fallback;
    return model.toLowerCase().startsWith("a_c_") ? "animal" : "human";
}

export function PedManager() {
    const t = useT();
    const [visible, setVisible] = useState(false);
    const [showMenu, setShowMenu] = useState(false);
    const [activeTab, setActiveTab] = useState<Tab>(Tab.MyPeds);
    const [categoryFilter, setCategoryFilter] = useState<CategoryFilter>(CategoryFilter.All);
    const [search, setSearch] = useState("");
    const [myPeds, setMyPeds] = useState<MyPed[]>([]);
    const [availablePeds, setAvailablePeds] = useState<AvailablePed[]>([]);
    const [_isAdmin, setIsAdmin] = useState(false);

    // ── NUI Events ──────────────────────────────────────────────────────
    useNuiEvent<OpenPedManagerData>("openPedManager", (data) => {
        setVisible(data.visible);
        if (data.visible) {
            setMyPeds(data.myPeds ?? []);
            setAvailablePeds(data.availablePeds ?? []);
            setIsAdmin(data.isAdmin ?? false);
            setActiveTab(Tab.MyPeds);
            setCategoryFilter(CategoryFilter.All);
            setSearch("");
        }
    });

    useNuiEvent<MyPed[]>("updateMyPeds", (data) => {
        if (Array.isArray(data)) setMyPeds(data);
    });

    useNuiEvent<{ strings: Record<string, string>; language?: string }>("setLocale", (data) => {
        if (data && typeof data === "object" && data.strings) {
            setLocaleStrings(data.strings as Record<string, string>, data.language);
        }
    });

    // ── Keyboard ────────────────────────────────────────────────────────
    const closeMenu = useCallback(() => {
        nuiCallback("closeMenu");
        setVisible(false);
    }, []);

    useEffect(() => {
        const handleKey = (e: KeyboardEvent) => {
            if (e.key === "Escape" && visible) closeMenu();
        };
        window.addEventListener("keydown", handleKey);
        return () => window.removeEventListener("keydown", handleKey);
    }, [visible, closeMenu]);

    // ── Animate ─────────────────────────────────────────────────────────
    useEffect(() => {
        if (visible) {
            const t = setTimeout(() => setShowMenu(true), 50);
            return () => clearTimeout(t);
        }
        setShowMenu(false);
    }, [visible]);

    // ── Actions ─────────────────────────────────────────────────────────
    const handleApply = useCallback(async (model: string) => {
        await nuiCallback("applyPed", { model });
    }, []);

    const handleSetDefault = useCallback(async (id: number, model: string) => {
        await nuiCallback("setDefaultPed", { id, model });
    }, []);

    const handleUnsetDefault = useCallback(async (id: number) => {
        await nuiCallback("unsetDefaultPed", { id });
    }, []);

    const handleRemove = useCallback(async (id: number) => {
        await nuiCallback("removePed", { id });
    }, []);

    const handleAdd = useCallback(async (model: string) => {
        await nuiCallback("addPed", { model });
    }, []);

    const handleReset = useCallback(async () => {
        await nuiCallback("resetPed");
    }, []);

    // ── Category presence in the available list (server-configurable) ──
    const availableCategories = useMemo(() => {
        const set = new Set<PedCategory>();
        for (const p of availablePeds) set.add(getCategory(p.model, p.category));
        return set;
    }, [availablePeds]);

    const showCategoryFilter = availableCategories.size > 1;

    const matchesCategory = useCallback(
        (model: string, category?: PedCategory) => {
            if (categoryFilter === CategoryFilter.All) return true;
            return getCategory(model, category) === categoryFilter;
        },
        [categoryFilter],
    );

    // ── Derived data ────────────────────────────────────────────────────
    const filteredAvailable = useMemo(() => {
        const q = search.toLowerCase();
        return availablePeds.filter(
            (p) =>
                matchesCategory(p.model, p.category) &&
                (!q || p.model.toLowerCase().includes(q)),
        );
    }, [availablePeds, search, matchesCategory]);

    const filteredMyPeds = useMemo(() => {
        const q = search.toLowerCase();
        return myPeds.filter(
            (p) => matchesCategory(p.ped) && (!q || p.ped.toLowerCase().includes(q)),
        );
    }, [myPeds, search, matchesCategory]);

    const myPedsCount = useMemo(
        () => myPeds.filter((p) => matchesCategory(p.ped)).length,
        [myPeds, matchesCategory],
    );
    const availableCount = useMemo(
        () => availablePeds.filter((p) => matchesCategory(p.model, p.category)).length,
        [availablePeds, matchesCategory],
    );

    const ownedSet = useMemo(() => new Set(myPeds.map((p) => p.ped)), [myPeds]);

    const imageMap = useMemo(() => {
        const map = new Map<string, string>();
        for (const p of availablePeds) map.set(p.model, p.image);
        return map;
    }, [availablePeds]);

    const getImage = useCallback(
        (model: string) => imageMap.get(model) ?? `https://docs.fivem.net/peds/${model}.webp`,
        [imageMap],
    );

    // ── Render ──────────────────────────────────────────────────────────
    const effectiveVisible = IS_BROWSER || visible;
    if (!effectiveVisible) return null;

    const show = showMenu || IS_BROWSER;

    return (
        <aside className={`pedmanager-panel flex flex-col ${show ? "is-visible" : ""}`}>
            {/* Header */}
            <div className="flex items-center justify-between px-5 py-3 border-b border-gray-700/60 shrink-0">
                <h2 className="text-lg font-bold text-white tracking-wide flex items-center gap-2">
                    <svg className="w-5 h-5 text-primary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                    {t("nui_title")}
                </h2>
                <button
                    onClick={closeMenu}
                    className="text-gray-400 hover:text-white transition p-1 rounded-lg hover:bg-gray-700/50"
                    title={t("nui_close")}
                >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                </button>
            </div>

            {/* Tabs + Search */}
            <div className="flex flex-wrap items-center gap-3 px-5 py-3 border-b border-gray-800/60 shrink-0">
                <div className="flex gap-1 bg-gray-800/60 rounded-lg p-1">
                    <TabButton
                        active={activeTab === Tab.MyPeds}
                        onClick={() => setActiveTab(Tab.MyPeds)}
                        label={t("nui_tab_mypeds")}
                        count={myPedsCount}
                    />
                    <TabButton
                        active={activeTab === Tab.Available}
                        onClick={() => setActiveTab(Tab.Available)}
                        label={t("nui_tab_available")}
                        count={availableCount}
                    />
                </div>
                <div className="flex-1 min-w-[140px]">
                    <div className="relative">
                        <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                        </svg>
                        <input
                            type="text"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            placeholder={t("nui_search_placeholder")}
                            className="pl-9 pr-3 py-2 w-full bg-gray-800/80 border border-gray-700 rounded-lg text-sm text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 transition"
                        />
                    </div>
                </div>
            </div>

            {/* Category filter chips – only when both categories are enabled server-side */}
            {showCategoryFilter && (
                <div className="flex items-center flex-wrap gap-2 px-5 py-2 border-b border-gray-800/60 shrink-0">
                    <span className="text-[11px] uppercase tracking-wider text-gray-500 font-semibold">{t("nui_category")}</span>
                    <CategoryChip
                        active={categoryFilter === CategoryFilter.All}
                        onClick={() => setCategoryFilter(CategoryFilter.All)}
                        label={t("nui_category_all")}
                    />
                    {availableCategories.has("human") && (
                        <CategoryChip
                            active={categoryFilter === CategoryFilter.Human}
                            onClick={() => setCategoryFilter(CategoryFilter.Human)}
                            label={t("nui_category_humans")}
                        />
                    )}
                    {availableCategories.has("animal") && (
                        <CategoryChip
                            active={categoryFilter === CategoryFilter.Animal}
                            onClick={() => setCategoryFilter(CategoryFilter.Animal)}
                            label={t("nui_category_animals")}
                        />
                    )}
                </div>
            )}

            {/* Content */}
            <div className="flex-1 overflow-y-auto p-4 scrollbar-thin">
                {activeTab === Tab.MyPeds && (
                    <>
                        {filteredMyPeds.length === 0 ? (
                            <EmptyState text={t("nui_empty_mypeds")} />
                        ) : (
                            <div className="grid grid-cols-2 xl:grid-cols-3 gap-3">
                                {filteredMyPeds.map((p) => (
                                    <PedCard
                                        key={p.id}
                                        model={p.ped}
                                        image={getImage(p.ped)}
                                        isDefault={!!p.is_default}
                                        actions={
                                            <div className="flex gap-1 w-full">
                                                <ActionBtn icon="▶" title={t("nui_action_apply")} color="primary" onClick={() => handleApply(p.ped)} />
                                                {p.is_default ? (
                                                    <ActionBtn icon="✦" title={t("nui_action_unset_default")} color="orange" onClick={() => handleUnsetDefault(p.id)} />
                                                ) : (
                                                    <ActionBtn icon="★" title={t("nui_action_set_default")} color="yellow" onClick={() => handleSetDefault(p.id, p.ped)} />
                                                )}
                                                <ActionBtn icon="✕" title={t("nui_action_remove")} color="red" onClick={() => handleRemove(p.id)} />
                                            </div>
                                        }
                                    />
                                ))}
                                <ResetCard onClick={handleReset} />
                            </div>
                        )}
                    </>
                )}

                {activeTab === Tab.Available && (
                    <>
                        {filteredAvailable.length === 0 ? (
                            <EmptyState text={t("nui_empty_filter")} />
                        ) : (
                            <div className="grid grid-cols-2 xl:grid-cols-3 gap-3">
                                {filteredAvailable.map((p) => {
                                    const owned = ownedSet.has(p.model);
                                    return (
                                        <PedCard
                                            key={p.model}
                                            model={p.model}
                                            image={p.image}
                                            owned={owned}
                                            custom={p.custom}
                                            actions={
                                                <div className="flex gap-1 w-full">
                                                    <ActionBtn icon="▶" title={t("nui_action_preview")} color="primary" onClick={() => handleApply(p.model)} />
                                                    {!owned && <ActionBtn icon="+" title={t("nui_action_add")} color="green" onClick={() => handleAdd(p.model)} />}
                                                </div>
                                            }
                                        />
                                    );
                                })}
                            </div>
                        )}
                    </>
                )}
            </div>
        </aside>
    );
}

interface CategoryChipProps {
    active: boolean;
    onClick: () => void;
    label: string;
    icon?: string;
}

function CategoryChip({ active, onClick, label, icon }: CategoryChipProps) {
    return (
        <button
            type="button"
            onClick={onClick}
            className={`px-2.5 py-1 rounded-full text-xs font-semibold border transition ${
                active
                    ? "bg-primary-600/80 border-primary-500 text-white"
                    : "bg-gray-800/60 border-gray-700 text-gray-300 hover:bg-gray-700/60 hover:text-white"
            }`}
        >
            {icon ? <span className="mr-1">{icon}</span> : null}
            {label}
        </button>
    );
}
