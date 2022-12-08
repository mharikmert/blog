const images = document.querySelectorAll('img');

images.forEach(image => {
    image.addEventListener('mouseover', () => {
        if (image.classList.contains('active')) {
            return;
        }
        images.forEach(image => image.classList.remove('active'));

        image.classList.add('active');

    });

    image.addEventListener('mouseout', () => {
        image.classList.remove('active');
    });

    image.addEventListener('click', () => {
        if (image.classList.contains('active')) {
            image.classList.remove('active');
        } else {
            image.classList.add('active');
        }
    });
});