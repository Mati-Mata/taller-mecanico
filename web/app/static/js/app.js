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

const clientType = document.querySelector("[data-client-type]");

function syncClientFields() {
    if (!clientType) {
        return;
    }
    const company = clientType.value === "empresa";
    document.querySelectorAll("[data-person-field]").forEach((field) => {
        field.hidden = company;
        field.querySelector("input").required = !company;
    });
    document.querySelectorAll("[data-company-field]").forEach((field) => {
        field.hidden = !company;
        field.querySelector("input").required = company;
    });
}

if (clientType) {
    clientType.addEventListener("change", syncClientFields);
    syncClientFields();
}

const paymentMethod = document.querySelector("[data-payment-method]");
const paymentReference = document.querySelector("[data-payment-reference]");

function syncPaymentReference() {
    if (paymentMethod && paymentReference) {
        paymentReference.required = paymentMethod.value !== "efectivo";
    }
}

if (paymentMethod) {
    paymentMethod.addEventListener("change", syncPaymentReference);
    syncPaymentReference();
}

const conceptSelector = document.querySelector("[data-concept-selector]");
const conceptType = document.querySelector("[data-concept-type]");

function syncConceptType() {
    if (conceptSelector && conceptType) {
        const option = conceptSelector.options[conceptSelector.selectedIndex];
        conceptType.value = option ? option.dataset.type || "" : "";
    }
}

if (conceptSelector) {
    conceptSelector.addEventListener("change", syncConceptType);
    syncConceptType();
}

document.querySelectorAll("form[data-confirm]").forEach((form) => {
    form.addEventListener("submit", (event) => {
        if (!window.confirm(form.dataset.confirm)) {
            event.preventDefault();
        }
    });
});

document.querySelectorAll("[data-print]").forEach((button) => {
    button.addEventListener("click", () => window.print());
});
