// main JS file
let slide_number = 0;

const slides = document.getElementsByClassName("slide");
const max_slide_number = slides.length - 1;

document.addEventListener("keydown", (e) => {
  if (e.key === "k" && slide_number > 0) {
    slide_number--;
    update_slide_visibility();
  } else if (e.key === "j" && slide_number < max_slide_number) {
    slide_number++;
    update_slide_visibility();
  } else if (e.key === "p") {
    update_slides_for_print();
  }
});

function update_slide_visibility() {
  for (i = 0; i <= max_slide_number; i++) {
    const element = document.getElementById("slide-" + i);
    element.style.display = "none";
  }

  const element = document.getElementById("slide-" + slide_number);
  element.style.display = "flex";
}

function update_slides_for_print() {
  for (i = 0; i <= max_slide_number; i++) {
    const element = document.getElementById("slide-" + i);
    element.style.display = "flex";
  }
}
