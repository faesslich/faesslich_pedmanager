export async function nuiCallback<T = unknown>(eventName: string, data: Record<string, unknown> = {}): Promise<T> {
    const resourceName = window.GetParentResourceName
        ? window.GetParentResourceName()
        : "nui-frame-app";

    const response = await fetch(`https://${resourceName}/${eventName}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data),
    });

    return response.json() as Promise<T>;
}

