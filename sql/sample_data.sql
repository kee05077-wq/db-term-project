-- sample data (every sample password is 1234)
USE instagram;

INSERT INTO `User` (user_id, password_hash, display_name) VALUES
  ('alice', 'pbkdf2_sha256$200000$5e3bb2bc4fc6ee8dcce70731ec1b8b7b$b3e3ed396c47ea0e386ab1272114c1e3b61880ca212d4897d35a17d6d6888115', 'Alice Kim'),
  ('bob', 'pbkdf2_sha256$200000$15730301b17b51095382d5daaf0c2ec0$42797eee78afa2461439370846dd9b286d33382c3717b0f956b042a768ef3dd7', 'Bob Lee'),
  ('carol', 'pbkdf2_sha256$200000$892cc3d5d53aa985999ab81b2a54d06d$de3fb69b490f2ecd77a731394d9ee9e4e6b327b2c004eb34a8bb73e96b3e4fa6', 'Carol Park'),
  ('dave', 'pbkdf2_sha256$200000$39473095df923a7578d2d7e6e764ef3f$fbe4397d7161b806edbd95b61112cd78f680d3e53179ffeafe0fbb2ac45ff42b', 'Dave Choi');

INSERT INTO Follow (follower_id, followee_id) VALUES
  ('alice', 'bob'), ('alice', 'carol'),
  ('bob', 'alice'), ('bob', 'carol'),
  ('carol', 'alice'),
  ('dave', 'carol');

INSERT INTO Post (author_id, image_path, caption, created_at) VALUES
  ('bob', 'sample/1.jpg', '주말 바다 🌊', '2026-11-15 14:20:00'),
  ('carol', 'sample/2.jpg', '오늘 하늘 색 미쳤다', '2026-11-16 18:05:00'),
  ('alice', 'sample/3.jpg', '카페에서 한 컷 ☕', '2026-11-17 11:30:00'),
  ('carol', 'sample/4.jpg', NULL, '2026-11-18 09:10:00'),
  ('bob', 'sample/5.jpg', '산책 중 @alice 랑', '2026-11-19 16:45:00'),
  ('dave', 'sample/6.jpg', '첫 게시물입니다', '2026-11-20 20:00:00'),
  ('carol', 'sample/7.jpg', '여행 사진 정리 중', '2026-11-21 13:15:00'),
  ('alice', 'sample/8.jpg', '가을 끝자락 🍂', '2026-11-22 17:40:00'),
  ('carol', 'sample/9.jpg', '@bob 이거 기억나?', '2026-11-23 21:05:00');

INSERT INTO Comment (post_id, author_id, text, created_at) VALUES
  (1, 'alice', '@bob 여기 어디야? 너무 예쁘다', '2026-11-15 15:00:00'),
  (1, 'carol', '나도 가고 싶다', '2026-11-15 15:30:00'),
  (1, 'bob', '@alice 강릉! 다음에 같이 가자', '2026-11-15 16:10:00'),
  (2, 'alice', '@carol 노을 진짜 예쁘네', '2026-11-16 19:00:00'),
  (5, 'alice', 'ㅋㅋ 사진 잘 나왔다', '2026-11-19 17:00:00'),
  (9, 'bob', '@carol 당연하지 ㅎㅎ', '2026-11-23 21:30:00');
