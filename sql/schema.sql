-- =============================================================
--  Instagram-style photo sharing service : schema (DDL)
--  MySQL 8.0
-- =============================================================

CREATE DATABASE IF NOT EXISTS instagram
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
USE instagram;

DROP TABLE IF EXISTS PhotoLocation;
DROP TABLE IF EXISTS Comment;
DROP TABLE IF EXISTS Follow;
DROP TABLE IF EXISTS Post;
DROP TABLE IF EXISTS `User`;

-- User(user_id, password_hash, display_name)
CREATE TABLE `User` (
  user_id       VARCHAR(30)  NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  display_name  VARCHAR(50)  NOT NULL,
  PRIMARY KEY (user_id)
);

-- Post(post_id, author_id, image_path, caption, created_at)
CREATE TABLE Post (
  post_id    INT          NOT NULL AUTO_INCREMENT,
  author_id  VARCHAR(30)  NOT NULL,
  image_path VARCHAR(255) NOT NULL,
  caption    TEXT         NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id),
  FOREIGN KEY (author_id) REFERENCES `User`(user_id)
);

-- Comment(comment_id, post_id, author_id, text, created_at)
CREATE TABLE Comment (
  comment_id INT         NOT NULL AUTO_INCREMENT,
  post_id    INT         NOT NULL,
  author_id  VARCHAR(30) NOT NULL,
  text       TEXT        NOT NULL,
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (comment_id),
  FOREIGN KEY (post_id)   REFERENCES Post(post_id),
  FOREIGN KEY (author_id) REFERENCES `User`(user_id)
);

-- Follow(follower_id, followee_id)
CREATE TABLE Follow (
  follower_id VARCHAR(30) NOT NULL,
  followee_id VARCHAR(30) NOT NULL,
  PRIMARY KEY (follower_id, followee_id),
  FOREIGN KEY (follower_id) REFERENCES `User`(user_id),
  FOREIGN KEY (followee_id) REFERENCES `User`(user_id),
  CHECK (follower_id <> followee_id)
);

-- index for the home-feed query (posts of an author, newest first)
CREATE INDEX idx_post_author_time ON Post(author_id, created_at);

-- Bonus: Photo location and travel timeline
CREATE TABLE PhotoLocation (
    post_id INT PRIMARY KEY,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    taken_at DATETIME NOT NULL,
    FOREIGN KEY (post_id) REFERENCES Post(post_id)
        ON DELETE CASCADE,
    CHECK (latitude BETWEEN -90 AND 90),
    CHECK (longitude BETWEEN -180 AND 180)
);
