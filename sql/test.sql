USE instagram;

-- 1. sign up test
START TRANSACTION;

INSERT INTO `User` (user_id, password_hash, display_name)
VALUES ('eve', 'test_hash_eve', 'Eve');

SELECT user_id, password_hash, display_name
FROM `User`
WHERE user_id = 'eve';

ROLLBACK;

-- 2. login test
SELECT user_id, password_hash
FROM `User`
WHERE user_id = 'alice';

-- 3. change password test
START TRANSACTION;

UPDATE `User`
SET password_hash = 'new_test_hash_alice'
WHERE user_id = 'alice';

SELECT user_id, password_hash
FROM `User`
WHERE user_id = 'alice';

ROLLBACK;

-- 4. follow test
START TRANSACTION;

INSERT INTO Follow (follower_id, followee_id)
VALUES ('carol', 'bob');

SELECT *
FROM Follow
WHERE follower_id = 'carol';

ROLLBACK;

-- 5. unfollow test
START TRANSACTION;

DELETE FROM Follow
WHERE follower_id = 'alice'
  AND followee_id = 'bob';

SELECT *
FROM Follow
WHERE follower_id = 'alice';

ROLLBACK;

-- 6. upload post test
START TRANSACTION;

INSERT INTO Post (author_id, image_path, caption)
VALUES ('alice', 'uploads/new_photo.jpg', 'New post!');

SELECT *
FROM Post
WHERE author_id = 'alice'
ORDER BY post_id DESC;

ROLLBACK;

-- 7. write comment test
START TRANSACTION;

INSERT INTO Comment (post_id, author_id, text)
VALUES (1, 'alice', '@bob Thank you!');

SELECT *
FROM Comment
WHERE post_id = 1
ORDER BY comment_id ASC;

ROLLBACK;

/*
-- 8-1. duplicate user test
START TRANSACTION;

INSERT INTO `User` (user_id, password_hash, display_name)
VALUES ('alice', 'test_hash', 'Another Alice');

ROLLBACK;

-- 8-2. duplicate follow test
START TRANSACTION;

INSERT INTO Follow (follower_id, followee_id)
VALUES ('alice', 'bob');

ROLLBACK;

-- 8-3. self-follow test
START TRANSACTION;

INSERT INTO Follow (follower_id, followee_id)
VALUES ('alice', 'alice');

ROLLBACK;

-- 8-4. foreign key test
START TRANSACTION;

INSERT INTO Follow (follower_id, followee_id)
VALUES ('alice', 'nonexistent_user');

ROLLBACK;
*/

-- 9. verify original data after rollback
SELECT
    (SELECT COUNT(*) FROM `User`) AS user_count,
    (SELECT COUNT(*) FROM Post) AS post_count,
    (SELECT COUNT(*) FROM Comment) AS comment_count,
    (SELECT COUNT(*) FROM Follow) AS follow_count;
    
-- 10. photo location insert test
START TRANSACTION;

INSERT INTO PhotoLocation
    (post_id, latitude, longitude, taken_at)
VALUES
    (2, 37.566500, 126.978000, '2026-11-16 17:00:00');

SELECT * FROM PhotoLocation
WHERE post_id = 2;

ROLLBACK;

-- 11. posts without location test
SELECT p.post_id, p.author_id
FROM Post p
LEFT JOIN PhotoLocation pl
    ON p.post_id = pl.post_id
WHERE pl.post_id IS NULL
ORDER BY p.post_id;

-- 12. cascade delete test
START TRANSACTION;

DELETE FROM Post
WHERE post_id = 7;

SELECT * FROM PhotoLocation
WHERE post_id = 7;

ROLLBACK;

SELECT * FROM PhotoLocation
WHERE post_id = 7;

-- 13. timeline date filtering test
SELECT p.post_id, pl.taken_at
FROM Post p
JOIN PhotoLocation pl
    ON p.post_id = pl.post_id
WHERE p.author_id = 'alice'
  AND pl.taken_at >= '2026-11-20'
  AND pl.taken_at < '2026-12-01'
ORDER BY pl.taken_at ASC;

/*
-- 14-1. duplicate photo location test
START TRANSACTION;

INSERT INTO PhotoLocation
VALUES (1, 37.566500, 126.978000, '2026-11-15 13:00:00');

ROLLBACK;


-- 14-2. foreign key test
START TRANSACTION;

INSERT INTO PhotoLocation
VALUES (9999, 37.566500, 126.978000, '2026-11-15 13:00:00');

ROLLBACK;


-- 14-3. invalid latitude test
START TRANSACTION;

INSERT INTO PhotoLocation
VALUES (2, 91.000000, 126.978000, '2026-11-16 17:00:00');

ROLLBACK;


-- 14-4. invalid longitude test
START TRANSACTION;

INSERT INTO PhotoLocation
VALUES (2, 37.566500, 181.000000, '2026-11-16 17:00:00');

ROLLBACK;
*/

-- 15. verify original data after rollback
SELECT
    (SELECT COUNT(*) FROM `User`) AS user_count,
    (SELECT COUNT(*) FROM Post) AS post_count,
    (SELECT COUNT(*) FROM Comment) AS comment_count,
    (SELECT COUNT(*) FROM Follow) AS follow_count,
    (SELECT COUNT(*) FROM PhotoLocation) AS location_count;
