-- COCO 데이터베이스 DDL
-- PostgreSQL 기준

CREATE TABLE users (
    user_id     BIGSERIAL    NOT NULL,
    email       VARCHAR(100) NOT NULL,
    password    VARCHAR(255) NOT NULL,
    nickname    VARCHAR(50)  NOT NULL,
    locale      VARCHAR(5),
    role        VARCHAR(10),
    created_at  TIMESTAMP    DEFAULT NOW(),
    nationality VARCHAR(10),
    PRIMARY KEY (user_id),
    CONSTRAINT uq_users_email UNIQUE (email)
);

CREATE TABLE spots (
    spot_id    BIGSERIAL    NOT NULL,
    tour_apiid VARCHAR(20),
    title_ko   VARCHAR(100),
    title_en   VARCHAR(100),
    title_ja   VARCHAR(100),
    lat        DOUBLE PRECISION,
    lng        DOUBLE PRECISION,
    address    VARCHAR(200),
    category   VARCHAR(20),
    image_url  TEXT,
    created_at TIMESTAMP    DEFAULT NOW(),
    PRIMARY KEY (spot_id)
);

CREATE TABLE qna_posts (
    qna_post_id BIGSERIAL    NOT NULL,
    user_id     BIGINT,
    question    VARCHAR(500),
    locale      VARCHAR(5),
    created_at  TIMESTAMP    DEFAULT NOW(),
    PRIMARY KEY (qna_post_id),
    CONSTRAINT fk_qna_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE qna_answers (
    qna_answer_id BIGSERIAL     NOT NULL,
    qna_post_id   BIGINT,
    user_id       BIGINT,
    content       VARCHAR(1000),
    adopted       BOOLEAN       DEFAULT FALSE,
    created_at    TIMESTAMP     DEFAULT NOW(),
    PRIMARY KEY (qna_answer_id),
    CONSTRAINT fk_ans_post FOREIGN KEY (qna_post_id) REFERENCES qna_posts(qna_post_id) ON DELETE CASCADE,
    CONSTRAINT fk_ans_user FOREIGN KEY (user_id)     REFERENCES users(user_id)         ON DELETE CASCADE
);

CREATE TABLE feed_posts (
    feed_post_id BIGSERIAL    NOT NULL,
    user_id      BIGINT,
    spot_id      BIGINT,
    image_url    TEXT,
    description  VARCHAR(500),
    like_count   INT          DEFAULT 0,
    created_at   TIMESTAMP    DEFAULT NOW(),
    PRIMARY KEY (feed_post_id),
    CONSTRAINT fk_feed_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_feed_spot FOREIGN KEY (spot_id) REFERENCES spots(spot_id) ON DELETE SET NULL
);

CREATE TABLE feed_comments (
    feed_comment_id BIGSERIAL    NOT NULL,
    feed_post_id    BIGINT,
    user_id         BIGINT,
    content         VARCHAR(300),
    created_at      TIMESTAMP    DEFAULT NOW(),
    PRIMARY KEY (feed_comment_id),
    CONSTRAINT fk_comment_post FOREIGN KEY (feed_post_id) REFERENCES feed_posts(feed_post_id) ON DELETE CASCADE,
    CONSTRAINT fk_comment_user FOREIGN KEY (user_id)      REFERENCES users(user_id)           ON DELETE CASCADE
);

CREATE TABLE spot_likes (
    spot_like_id BIGSERIAL NOT NULL,
    user_id      BIGINT,
    spot_id      BIGINT,
    created_at   TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (spot_like_id),
    CONSTRAINT fk_slike_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_slike_spot FOREIGN KEY (spot_id) REFERENCES spots(spot_id) ON DELETE CASCADE,
    CONSTRAINT uq_spot_like  UNIQUE (user_id, spot_id)
);

CREATE TABLE feed_post_likes (
    feed_post_like_id BIGSERIAL NOT NULL,
    user_id           BIGINT,
    feed_post_id      BIGINT,
    created_at        TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (feed_post_like_id),
    CONSTRAINT fk_flike_user FOREIGN KEY (user_id)      REFERENCES users(user_id)           ON DELETE CASCADE,
    CONSTRAINT fk_flike_post FOREIGN KEY (feed_post_id) REFERENCES feed_posts(feed_post_id) ON DELETE CASCADE,
    CONSTRAINT uq_feed_like  UNIQUE (user_id, feed_post_id)
);

-- 인덱스
CREATE INDEX idx_feed_user      ON feed_posts      (user_id);
CREATE INDEX idx_feed_spot      ON feed_posts      (spot_id);
CREATE INDEX idx_feed_created   ON feed_posts      (created_at DESC);
CREATE INDEX idx_comment_post   ON feed_comments   (feed_post_id);
CREATE INDEX idx_qna_user       ON qna_posts       (user_id);
CREATE INDEX idx_ans_post       ON qna_answers     (qna_post_id);
CREATE INDEX idx_slike_user     ON spot_likes      (user_id);
CREATE INDEX idx_flike_user     ON feed_post_likes (user_id);
CREATE INDEX idx_spot_loc       ON spots           (lat, lng);
