-- =============================================================
--  SQL used by the web application (app.py)
--  %s in app.py = parameter; here shown with example values
--  Execute individual statements only
--  Use test.sql for transaction-based testing
-- =============================================================
USE instagram;

-- [5.1] sign up
INSERT INTO `User` (user_id, password_hash, display_name) VALUES ('eve', '<hash>', 'Eve');

-- [5.1] log in (password is checked against the stored hash in Python)
SELECT user_id, password_hash FROM `User` WHERE user_id = 'alice';

-- [5.1] change password
UPDATE `User` SET password_hash = '<new hash>' WHERE user_id = 'alice';

-- [5.2] follow (no approval needed) / unfollow
INSERT IGNORE INTO Follow (follower_id, followee_id) VALUES ('alice', 'dave');
DELETE FROM Follow WHERE follower_id = 'alice' AND followee_id = 'dave';

-- [5.2] followers of alice
SELECT u.user_id, u.display_name
FROM Follow f JOIN `User` u ON u.user_id = f.follower_id
WHERE f.followee_id = 'alice'
ORDER BY u.user_id;

-- [5.2] users alice follows
SELECT u.user_id, u.display_name
FROM Follow f JOIN `User` u ON u.user_id = f.followee_id
WHERE f.follower_id = 'alice'
ORDER BY u.user_id;

-- [5.3] upload a photo with a caption
INSERT INTO Post (author_id, image_path, caption) VALUES ('alice', 'uploads/abc.jpg', 'hello');

-- [5.3] comment (an @ID mention is stored inside the text)
INSERT INTO Comment (post_id, author_id, text) VALUES (1, 'alice', '@bob nice shot!');

-- [5.3] home feed: my posts + posts of users I follow, newest first
SELECT p.post_id, p.author_id, p.image_path, p.caption, p.created_at, u.display_name
FROM Post p JOIN `User` u ON u.user_id = p.author_id
WHERE p.author_id = 'alice'
   OR p.author_id IN (SELECT followee_id FROM Follow WHERE follower_id = 'alice')
ORDER BY p.created_at DESC, p.post_id DESC
LIMIT 50;

-- [5.3] comments of a post
SELECT comment_id, post_id, author_id, text, created_at
FROM Comment WHERE post_id = 1
ORDER BY created_at, comment_id;

-- [5.3] profile: header counts
SELECT (SELECT COUNT(*) FROM Post   WHERE author_id   = 'carol') AS posts,
       (SELECT COUNT(*) FROM Follow WHERE followee_id = 'carol') AS followers,
       (SELECT COUNT(*) FROM Follow WHERE follower_id = 'carol') AS following;

-- [5.3] profile: photo grid
SELECT p.post_id, p.image_path,
       (SELECT COUNT(*) FROM Comment c WHERE c.post_id = p.post_id) AS comment_count
FROM Post p WHERE p.author_id = 'carol'
ORDER BY p.created_at DESC, p.post_id DESC;

-- [bonus] user search by id or name
SELECT user_id, display_name FROM `User`
WHERE user_id LIKE '%car%' OR display_name LIKE '%car%'
ORDER BY user_id LIMIT 30;

-- feed sidebar: users I do not follow yet
SELECT u.user_id, u.display_name FROM `User` u
WHERE u.user_id <> 'alice'
  AND u.user_id NOT IN (SELECT followee_id FROM Follow WHERE follower_id = 'alice')
ORDER BY RAND() LIMIT 5;

-- [bonus] save photo location
INSERT INTO PhotoLocation
    (post_id, latitude, longitude, taken_at)
VALUES
    (2, 37.566500, 126.978000, '2026-11-16 17:00:00');
    
-- [bonus] travel timeline by date range
SELECT Post.image_path,
       PhotoLocation.latitude,
       PhotoLocation.longitude,
       PhotoLocation.taken_at
FROM Post
JOIN PhotoLocation ON Post.post_id = PhotoLocation.post_id
WHERE Post.author_id = 'alice'
  AND PhotoLocation.taken_at >= '2026-11-01'
  AND PhotoLocation.taken_at < '2026-12-01'
ORDER BY PhotoLocation.taken_at ASC, Post.post_id ASC;

-- [bonus] get location of a post
SELECT latitude, longitude, taken_at
FROM PhotoLocation
WHERE post_id = 1;
