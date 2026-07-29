"use strict";

document.querySelectorAll("[data-flash-close]").forEach((button) => {
    button.addEventListener("click", () => {
        const alert = button.closest(".alert");
        if (alert) {
            alert.remove();
        }
    });
});

const toggle = document.querySelector("[data-sidebar-toggle]");
const closeTargets = document.querySelectorAll("[data-sidebar-close]");

if (toggle) {
    toggle.addEventListener("click", () => {
        document.body.classList.toggle("sidebar-open");
    });
}

closeTargets.forEach((target) => {
    target.addEventListener("click", () => {
        document.body.classList.remove("sidebar-open");
    });
});
