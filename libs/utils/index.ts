// Shared helper modules for the project.

export const formatDate = (date: Date): string => {
    return date.toISOString().split("T")[0];
};
