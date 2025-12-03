CREATE TABLE place(
    place_id INT PRIMARY KEY,
    name VARCHAR(50),
    phone VARCHAR(10)
);

CREATE TABLE musician(
    musician_id INT PRIMARY KEY,
    ssn VARCHAR(13),
    Name VARCHAR(50)
);

CREATE TABLE live(
    place_id INT,
    musician_id INT,
    since DATE,
    PRIMARY KEY (place_id, musician_id),
    FOREIGN KEY (place_id) REFERENCES place(place_id),
    FOREIGN KEY (musician_id) REFERENCES musician(musician_id)
);

CREATE TABLE instrument(
    instrument_id INT PRIMARY KEY,
    name VARCHAR(50),
    key VARCHAR(20)
);

CREATE TABLE play(
    play_id INT PRIMARY KEY,
    musician_id INT,
    instrument_id INT,
    FOREIGN KEY (musician_id) REFERENCES musician(musician_id),
    FOREIGN KEY (instrument_id) REFERENCES instrument(instrument_id)
);

CREATE TABLE album(
    album_id INT PRIMARY KEY,
    title VARCHAR(50),
    copyright_date DATE,
    format VARCHAR(50),
    album_identifier VARCHAR(50)
);

CREATE TABLE song(
    song_id INT PRIMARY KEY,
    title VARCHAR(100),
    author VARCHAR(50),
    album_id INT NOT NULL,
    FOREIGN KEY (album_id) REFERENCES album(album_id)
);

CREATE TABLE perform(
    perform_id INT PRIMARY KEY,
    musician_id INT,
    song_id INT,
    perform_date DATE,
    perform_place VARCHAR(100),
    FOREIGN KEY (musician_id) REFERENCES musician(musician_id)
);

ALTER TABLE album ADD column producer_id INT;
ALTER TABLE album ADD CONSTRAINT fk_producer_id FOREIGN KEY (producer_id) REFERENCES musician(musician_id);