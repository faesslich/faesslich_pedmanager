export type PedCategory = "animal" | "human";

export interface MyPed {
    id: number;
    ped: string;
    is_default: number; // 0 | 1 from MySQL
}

export interface AvailablePed {
    model: string;
    image: string;
    custom: boolean;
    category?: PedCategory;
}

export interface OpenPedManagerData {
    visible: boolean;
    myPeds?: MyPed[];
    availablePeds?: AvailablePed[];
    isAdmin?: boolean;
}

export type ButtonColor = "primary" | "green" | "red" | "yellow" | "orange";

export const enum Tab {
    MyPeds = "mypeds",
    Available = "available",
}

export const enum CategoryFilter {
    All = "all",
    Human = "human",
    Animal = "animal",
}

