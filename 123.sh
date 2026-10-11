#! bin/bash


controllers/

                                                          auth_controller.py
"""Управление авторизацией."""
from models.user import find_by_login

_current_user = None


def login(login_name):
    global _current_user
    user = find_by_login(login_name.strip())
    if user is None:
        return False, 'Пользователь с таким логином не найден'
    _current_user = user
    return True, user


def logout():
    global _current_user
    _current_user = None


def current_user():
    return _current_user


    catalog_controller.py
"""Логика каталога."""
from models.product import list_products, get_product, get_sizes_for_product, list_categories


def get_catalog(category_id=None, search='', sort=''):
    return list_products(category_id=category_id, search=search, sort=sort)


def get_product_details(product_id):
    product = get_product(product_id)
    if not product:
        return None, []
    sizes = get_sizes_for_product(product_id)
    return product, sizes


def get_all_categories():
    return list_categories()


                                                    catalog_controller.py

from models.product import list_products, get_product, get_sizes_for_product, list_categories


def get_catalog(category_id=None, search='', sort=''):
    return list_products(category_id=category_id, search=search, sort=sort)


def get_product_details(product_id):
    product = get_product(product_id)
    if not product:
        return None, []
    sizes = get_sizes_for_product(product_id)
    return product, sizes


def get_all_categories():
    return list_categories()


                                                          discount.py
    """Расчёт скидки 25%."""
from datetime import datetime, timedelta
from db.connection import get_connection, release_connection


def get_previous_month_range():
    today = datetime.now().date()
    first_of_current = today.replace(day=1)
    last_of_prev = first_of_current - timedelta(days=1)
    first_of_prev = last_of_prev.replace(day=1)
    return first_of_prev, first_of_current


def has_orders_last_month(product_id):
    start, end = get_previous_month_range()
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT COUNT(*) FROM order_items oi
            JOIN stock_items si ON si.stock_item_id = oi.stock_item_id
            JOIN orders o ON o.order_id = oi.order_id
            WHERE si.product_id = %s
              AND o.order_date >= %s
              AND o.order_date < %s
        """, (product_id, start, end))
        return cur.fetchone()[0] > 0
    finally:
        release_connection(conn)


def calculate_final_price(product_id, base_price):
    if has_orders_last_month(product_id):
        return float(base_price), 0
    return round(float(base_price) * 0.75, 2), 25


                                                     order_controller.py
    """Логика заказов."""
from models.order import (list_orders, get_order, create_order,
                          delete_order, update_order, create_order_manual)


def get_all_orders():
    return list_orders()


def get_user_orders(user_id):
    return list_orders(user_id=user_id)


def get_order_details(order_id):
    return get_order(order_id)


def place_order(user_id, items):
    if not items:
        raise ValueError('Заказ пуст')
    return create_order(user_id, items)


def place_manual_order(user_id, order_date, items):
    if not items:
        raise ValueError('Заказ пуст')
    return create_order_manual(user_id, order_date, items)


def remove_order(order_id):
    delete_order(order_id)


def edit_order(order_id, new_date, remove_item_ids):
    update_order(order_id, new_date, remove_item_ids)


                                                                db/
                                                           connection.py
    #"""Модуль подключения к PostgreSQL."""
import psycopg2
from psycopg2 import pool
import os

DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'port': int(os.environ.get('DB_PORT', 5432)),
    'database': os.environ.get('DB_NAME', 'chudo_obuv'),
    'user': os.environ.get('DB_USER', 'obuv_user'),
    'password': os.environ.get('DB_PASSWORD', 'obuv_pass'),
}

_connection_pool = None


def init_pool():
    global _connection_pool
    if _connection_pool is None:
        _connection_pool = pool.SimpleConnectionPool(
            minconn=1, maxconn=5, **DB_CONFIG
        )
    return _connection_pool


def get_connection():
    if _connection_pool is None:
        init_pool()
    return _connection_pool.getconn()


def release_connection(conn):
    if _connection_pool is not None and conn is not None:
        _connection_pool.putconn(conn)


def close_all():
    global _connection_pool
    if _connection_pool is not None:
        _connection_pool.closeall()
        _connection_pool = None


                                                          demo_data.sql
        -- Демо-данные для «Чудо Обувь»
-- 1. Категории и производители (на случай, если seed.sql не применён)
INSERT INTO categories (category_name) VALUES
    ('Детская обувь'), ('Женская обувь'), ('Мужская обувь')
ON CONFLICT DO NOTHING;

INSERT INTO manufacturers (manufacturer_name) VALUES
    ('Малыш-Спорт'), ('Топ-Топ'), ('Барбари'), ('Стиль и комфорт')
ON CONFLICT DO NOTHING;

-- 2. Пользователи (3 роли)
INSERT INTO users (last_name, first_name, middle_name, login, role_id)
VALUES
    ('Иванов', 'Иван', 'Иванович', 'isivanov',
        (SELECT role_id FROM roles WHERE role_name = 'Администратор')),
    ('Петров', 'Павел', 'Петрович', 'papetrov',
        (SELECT role_id FROM roles WHERE role_name = 'Менеджер')),
    ('Сидорова', 'Анна', 'Сергеевна', 'asidorova',
        (SELECT role_id FROM roles WHERE role_name = 'Авторизованный пользователь'))
ON CONFLICT (login) DO NOTHING;

-- 3. Размеры
INSERT INTO sizes (size_value) VALUES
    ('35'), ('36'), ('37'), ('38'), ('39'), ('40'),
    ('41'), ('42'), ('43'), ('44'), ('45')
ON CONFLICT (size_value) DO NOTHING;

-- 4. Товары
INSERT INTO products (category_id, manufacturer_id, subcategory, product_name,
                      image_path, description, composition, price)
VALUES
    ((SELECT category_id FROM categories WHERE category_name = 'Женская обувь'),
     (SELECT manufacturer_id FROM manufacturers WHERE manufacturer_name = 'Стиль и комфорт'),
     'Туфли', 'Туфли женские классические',
     'IMG_01.png', 'Элегантные туфли на каблуке для повседневной носки.',
     'Натуральная кожа', 4500.00),

    ((SELECT category_id FROM categories WHERE category_name = 'Женская обувь'),
     (SELECT manufacturer_id FROM manufacturers WHERE manufacturer_name = 'Барбари'),
     'Кроссовки', 'Кроссовки женские спортивные',
     'IMG_02.png', 'Удобные кроссовки для бега и прогулок.',
     'Текстиль, резина', 3200.00),

    ((SELECT category_id FROM categories WHERE category_name = 'Мужская обувь'),
     (SELECT manufacturer_id FROM manufacturers WHERE manufacturer_name = 'Стиль и комфорт'),
     'Ботинки', 'Ботинки мужские кожаные',
     'IMG_03.png', 'Прочные ботинки для осенне-зимнего сезона.',
     'Натуральная кожа', 6800.00),

    ((SELECT category_id FROM categories WHERE category_name = 'Мужская обувь'),
     (SELECT manufacturer_id FROM manufacturers WHERE manufacturer_name = 'Топ-Топ'),
     'Кроссовки', 'Кроссовки мужские',
     'IMG_04.png', 'Лёгкие кроссовки для активного отдыха.',
     'Текстиль', 2900.00),

    ((SELECT category_id FROM categories WHERE category_name = 'Детская обувь'),
     (SELECT manufacturer_id FROM manufacturers WHERE manufacturer_name = 'Малыш-Спорт'),
     'Кроссовки', 'Кроссовки детские',
     'IMG_05.png', 'Яркие кроссовки для детей.',
     'Текстиль', 1800.00),

    ((SELECT category_id FROM categories WHERE category_name = 'Детская обувь'),
     (SELECT manufacturer_id FROM manufacturers WHERE manufacturer_name = 'Барбари'),
     'Сандалии', 'Сандалии детские',
     'IMG_06.png', 'Лёгкие сандалии для лета.',
     'Кожа, текстиль', 1500.00),

    ((SELECT category_id FROM categories WHERE category_name = 'Женская обувь'),
     (SELECT manufacturer_id FROM manufacturers WHERE manufacturer_name = 'Барбари'),
     'Сапоги', 'Сапоги женские зимние',
     'IMG_07.png', 'Тёплые сапоги для суровой зимы.',
     'Натуральная кожа, мех', 8500.00),

    ((SELECT category_id FROM categories WHERE category_name = 'Мужская обувь'),
     (SELECT manufacturer_id FROM manufacturers WHERE manufacturer_name = 'Стиль и комфорт'),
     'Туфли', 'Туфли мужские классические',
     'IMG_08.png', 'Строгие туфли для деловых встреч.',
     'Натуральная кожа', 5500.00)
ON CONFLICT (product_name, manufacturer_id) DO NOTHING;

-- 5. Склад: размеры 37-42, по 10 шт.
INSERT INTO stock_items (product_id, size_id, quantity_available)
SELECT p.product_id, s.size_id, 10
FROM products p CROSS JOIN sizes s
WHERE s.size_value IN ('37', '38', '39', '40', '41', '42')
ON CONFLICT (product_id, size_id) DO NOTHING;

-- 6. Товар с малым остатком (для подсветки ≤ 3)
UPDATE stock_items
SET quantity_available = 2
WHERE product_id = (
    SELECT product_id FROM products
    WHERE product_name = 'Кроссовки женские спортивные'
)
AND size_id = (SELECT size_id FROM sizes WHERE size_value = '37');



                                                       import_data.py
"""Импорт данных из xlsx в PostgreSQL."""
import os
import sys
import openpyxl

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from db.connection import get_connection, release_connection

DATA_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'data'
)


def read_xlsx(filename):
    path = os.path.join(DATA_DIR, filename)
    if not os.path.exists(path):
        print(f'[!] Файл не найден: {path}, пропускаем.')
        return []
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))
    return rows[1:]


def get_or_create(cur, table, id_col, name_col, name):
    name = (name or '').strip()
    cur.execute(f"SELECT {id_col} FROM {table} WHERE {name_col} = %s", (name,))
    row = cur.fetchone()
    if row:
        return row[0]
    cur.execute(f"INSERT INTO {table} ({name_col}) VALUES (%s) RETURNING {id_col}", (name,))
    return cur.fetchone()[0]


def import_roles(cur):
    for r in ['Администратор', 'Менеджер', 'Авторизованный пользователь']:
        cur.execute("INSERT INTO roles (role_name) VALUES (%s) ON CONFLICT DO NOTHING", (r,))


def import_users(cur):
    for row in read_xlsx('Users_import.xlsx'):
        if len(row) < 5 or not row[3]:
            continue
        cur.execute("SELECT role_id FROM roles WHERE role_name = %s", (row[4],))
        r = cur.fetchone()
        if not r:
            continue
        cur.execute("""
            INSERT INTO users (last_name, first_name, middle_name, login, role_id)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (login) DO NOTHING
        """, (row[0], row[1], row[2], row[3], r[0]))


def import_sizes(cur):
    for row in read_xlsx('Sizes_import.xlsx'):
        if row and row[0] is not None:
            cur.execute("INSERT INTO sizes (size_value) VALUES (%s) ON CONFLICT DO NOTHING",
                        (str(row[0]).strip(),))


def import_products(cur):
    for row in read_xlsx('Products_import.xlsx'):
        if len(row) < 8 or not row[3]:
            continue
        cat_id = get_or_create(cur, 'categories', 'category_id', 'category_name', row[0])
        man_id = get_or_create(cur, 'manufacturers', 'manufacturer_id', 'manufacturer_name', row[4])
        cur.execute("""
            INSERT INTO products (category_id, manufacturer_id, subcategory,
                product_name, image_path, description, composition, price)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (product_name, manufacturer_id) DO UPDATE
                SET price = EXCLUDED.price
        """, (cat_id, man_id, row[1], row[3], row[2], row[5], row[6], float(row[7])))


def main():
    conn = get_connection()
    cur = conn.cursor()
    try:
        import_roles(cur)
        import_users(cur)
        import_sizes(cur)
        import_products(cur)
        conn.commit()
        print('[OK] Импорт завершён (или пропущен, если файлов нет).')
    except Exception as e:
        conn.rollback()
        print(f'[ОШИБКА] {e}')
    finally:
        cur.close()
        release_connection(conn)


if __name__ == '__main__':
    main()
                                                        schema.sql
-- Схема БД «Чудо Обувь»
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS stock_items CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS sizes CASCADE;
DROP TABLE IF EXISTS manufacturers CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

CREATE TABLE roles (
    role_id    SERIAL PRIMARY KEY,
    role_name  VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE users (
    user_id      SERIAL PRIMARY KEY,
    last_name    VARCHAR(100) NOT NULL,
    first_name   VARCHAR(100) NOT NULL,
    middle_name  VARCHAR(100),
    login        VARCHAR(50) NOT NULL UNIQUE,
    role_id      INTEGER NOT NULL REFERENCES roles(role_id)
);

CREATE TABLE categories (
    category_id    SERIAL PRIMARY KEY,
    category_name  VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE manufacturers (
    manufacturer_id    SERIAL PRIMARY KEY,
    manufacturer_name  VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE products (
    product_id       SERIAL PRIMARY KEY,
    category_id      INTEGER NOT NULL REFERENCES categories(category_id),
    manufacturer_id  INTEGER NOT NULL REFERENCES manufacturers(manufacturer_id),
    subcategory      VARCHAR(100),
    product_name     VARCHAR(250) NOT NULL,
    image_path       VARCHAR(255),
    description      TEXT,
    composition      TEXT,
    price            NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    UNIQUE (product_name, manufacturer_id)
);

CREATE TABLE sizes (
    size_id     SERIAL PRIMARY KEY,
    size_value  VARCHAR(10) NOT NULL UNIQUE
);

CREATE TABLE stock_items (
    stock_item_id      SERIAL PRIMARY KEY,
    product_id         INTEGER NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    size_id            INTEGER NOT NULL REFERENCES sizes(size_id),
    quantity_available INTEGER NOT NULL DEFAULT 0 CHECK (quantity_available >= 0),
    UNIQUE (product_id, size_id)
);

CREATE TABLE orders (
    order_id    SERIAL PRIMARY KEY,
    order_date  DATE NOT NULL,
    user_id     INTEGER NOT NULL REFERENCES users(user_id)
);

CREATE TABLE order_items (
    order_item_id  SERIAL PRIMARY KEY,
    order_id       INTEGER NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    stock_item_id  INTEGER NOT NULL REFERENCES stock_items(stock_item_id),
    quantity       INTEGER NOT NULL CHECK (quantity > 0),
    price          NUMERIC(10, 2) NOT NULL CHECK (price >= 0)
);

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_manufacturer ON products(manufacturer_id);
CREATE INDEX idx_stock_items_product ON stock_items(product_id);
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_stock ON order_items(stock_item_id);

INSERT INTO roles (role_name) VALUES
    ('Администратор'),
    ('Менеджер'),
    ('Авторизованный пользователь');


                                                     seed.sql
-- Демо-данные
INSERT INTO categories (category_name) VALUES
    ('Детская обувь'),
    ('Женская обувь'),
    ('Мужская обувь')
ON CONFLICT DO NOTHING;

INSERT INTO manufacturers (manufacturer_name) VALUES
    ('Малыш-Спорт'),
    ('Топ-Топ'),
    ('Барбари'),
    ('Стиль и комфорт')
ON CONFLICT DO NOTHING;


                                                      models/
                                                    order.py
"""Работа с заказами."""
from db.connection import get_connection, release_connection
from models import stock as stock_model


class Order:
    def __init__(self, order_id, order_date, user_id, fio):
        self.order_id = order_id
        self.order_date = order_date
        self.user_id = user_id
        self.fio = fio


def list_orders(user_id=None):
    conn = get_connection()
    try:
        cur = conn.cursor()
        if user_id:
            cur.execute("""
                SELECT o.order_id, o.order_date, o.user_id,
                       u.last_name || ' ' || u.first_name || ' ' || COALESCE(u.middle_name, '')
                FROM orders o
                JOIN users u ON u.user_id = o.user_id
                WHERE o.user_id = %s
                ORDER BY o.order_id DESC
            """, (user_id,))
        else:
            cur.execute("""
                SELECT o.order_id, o.order_date, o.user_id,
                       u.last_name || ' ' || u.first_name || ' ' || COALESCE(u.middle_name, '')
                FROM orders o
                JOIN users u ON u.user_id = o.user_id
                ORDER BY o.order_id DESC
            """)
        return [Order(*row) for row in cur.fetchall()]
    finally:
        release_connection(conn)


def get_order(order_id):
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT o.order_id, o.order_date, o.user_id,
                   u.last_name || ' ' || u.first_name || ' ' || COALESCE(u.middle_name, '')
            FROM orders o
            JOIN users u ON u.user_id = o.user_id
            WHERE o.order_id = %s
        """, (order_id,))
        row = cur.fetchone()
        if not row:
            return None
        order = Order(*row)
        cur.execute("""
            SELECT oi.order_item_id, oi.quantity, oi.price,
                   p.product_name, m.manufacturer_name, sz.size_value
            FROM order_items oi
            JOIN stock_items si ON si.stock_item_id = oi.stock_item_id
            JOIN products p ON p.product_id = si.product_id
            JOIN manufacturers m ON m.manufacturer_id = p.manufacturer_id
            JOIN sizes sz ON sz.size_id = si.size_id
            WHERE oi.order_id = %s
            ORDER BY oi.order_item_id
        """, (order_id,))
        order.items = cur.fetchall()
        order.total = sum(it[1] * float(it[2]) for it in order.items)
        return order
    finally:
        release_connection(conn)


def create_order(user_id, items):
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO orders (order_date, user_id)
            VALUES (CURRENT_DATE, %s) RETURNING order_id
        """, (user_id,))
        order_id = cur.fetchone()[0]
        for item in items:
            stock_id = item['stock_item_id']
            qty = item['quantity']
            stock_model.decrease_quantity(cur, stock_id, qty)
            cur.execute("""
                SELECT p.price FROM stock_items si
                JOIN products p ON p.product_id = si.product_id
                WHERE si.stock_item_id = %s
            """, (stock_id,))
            price = cur.fetchone()[0]
            cur.execute("""
                INSERT INTO order_items (order_id, stock_item_id, quantity, price)
                VALUES (%s, %s, %s, %s)
            """, (order_id, stock_id, qty, price))
        conn.commit()
        return order_id
    except Exception:
        conn.rollback()
        raise
    finally:
        release_connection(conn)


def create_order_manual(user_id, order_date, items):
    """Ручное создание заказа (Менеджер/Администратор)."""
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO orders (order_date, user_id)
            VALUES (%s, %s) RETURNING order_id
        """, (order_date, user_id))
        order_id = cur.fetchone()[0]
        for item in items:
            stock_id = item['stock_item_id']
            qty = item['quantity']
            price = item['price']
            stock_model.decrease_quantity(cur, stock_id, qty)
            cur.execute("""
                INSERT INTO order_items (order_id, stock_item_id, quantity, price)
                VALUES (%s, %s, %s, %s)
            """, (order_id, stock_id, qty, price))
        conn.commit()
        return order_id
    except Exception:
        conn.rollback()
        raise
    finally:
        release_connection(conn)


def delete_order(order_id):
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT stock_item_id, quantity FROM order_items WHERE order_id = %s", (order_id,))
        for stock_id, qty in cur.fetchall():
            stock_model.increase_quantity(cur, stock_id, qty)
        cur.execute("DELETE FROM orders WHERE order_id = %s", (order_id,))
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        release_connection(conn)


def update_order(order_id, new_date, remove_item_ids):
    conn = get_connection()
    try:
        cur = conn.cursor()
        if new_date:
            cur.execute("UPDATE orders SET order_date = %s WHERE order_id = %s",
                        (new_date, order_id))
        for item_id in remove_item_ids:
            cur.execute("SELECT stock_item_id, quantity FROM order_items WHERE order_item_id = %s",
                        (item_id,))
            row = cur.fetchone()
            if row:
                stock_model.increase_quantity(cur, row[0], row[1])
                cur.execute("DELETE FROM order_items WHERE order_item_id = %s", (item_id,))
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        release_connection(conn)

                                                       product.py

"""Работа с товарами."""
from db.connection import get_connection, release_connection


class Product:
    def __init__(self, product_id, product_name, category_name, manufacturer_name,
                 subcategory, image_path, description, composition, price,
                 total_quantity, base_price, final_price, discount_percent):
        self.product_id = product_id
        self.product_name = product_name
        self.category_name = category_name
        self.manufacturer_name = manufacturer_name
        self.subcategory = subcategory or ''
        self.image_path = image_path or ''
        self.description = description or ''
        self.composition = composition or ''
        self.price = base_price
        self.total_quantity = total_quantity
        self.base_price = base_price
        self.final_price = final_price
        self.discount_percent = discount_percent

    @property
    def availability(self):
        return 'много' if self.total_quantity > 5 else 'мало'

    @property
    def is_low_stock(self):
        return self.total_quantity <= 3



def list_products(category_id=None, search='', sort=''):
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT (CURRENT_DATE - INTERVAL '1 month')::date,
                   (CURRENT_DATE)::date
        """)
        prev_start, prev_end = cur.fetchone()

        query = """
            SELECT p.product_id, p.product_name, c.category_name, m.manufacturer_name,
                   p.subcategory, p.image_path, p.description, p.composition, p.price,
                   COALESCE((SELECT SUM(quantity_available) FROM stock_items
                             WHERE product_id = p.product_id), 0) AS total_quantity,
                   (SELECT COUNT(*) FROM order_items oi
                       JOIN stock_items si ON si.stock_item_id = oi.stock_item_id
                       JOIN orders o ON o.order_id = oi.order_id
                       WHERE si.product_id = p.product_id
                         AND o.order_date >= %s AND o.order_date < %s)
            FROM products p
            JOIN categories c ON c.category_id = p.category_id
            JOIN manufacturers m ON m.manufacturer_id = p.manufacturer_id
        """
        params = [prev_start, prev_end]
        where = []
        if category_id:
            where.append("c.category_id = %s")
            params.append(category_id)
        if search:
            where.append("(LOWER(p.product_name) LIKE %s OR LOWER(p.description) LIKE %s)")
            params.extend([f'%{search.lower()}%', f'%{search.lower()}%'])
        if where:
            query += " WHERE " + " AND ".join(where)

        cur.execute(query, params)
        result = []
        for row in cur.fetchall():
            (pid, name, cat, man, subcat, image, descr, comp, price,
             total_qty, orders_last) = row
            discount = 25 if orders_last == 0 else 0
            final_price = round(float(price) * (100 - discount) / 100, 2)
            result.append(Product(pid, name, cat, man, subcat, image, descr, comp,
                                  float(price), int(total_qty), float(price),
                                  final_price, discount))
        if sort == 'price_asc':
            result.sort(key=lambda p: p.final_price)
        elif sort == 'price_desc':
            result.sort(key=lambda p: p.final_price, reverse=True)
        return result
    finally:
        release_connection(conn)




def get_product(product_id):
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT p.product_id, p.product_name, c.category_name, m.manufacturer_name,
                   p.subcategory, p.image_path, p.description, p.composition, p.price,
                   COALESCE((SELECT SUM(quantity_available) FROM stock_items
                             WHERE product_id = p.product_id), 0),
                   (SELECT COUNT(*) FROM order_items oi
                       JOIN stock_items si ON si.stock_item_id = oi.stock_item_id
                       JOIN orders o ON o.order_id = oi.order_id
                       WHERE si.product_id = p.product_id
                         AND o.order_date >= (CURRENT_DATE - INTERVAL '1 month')::date
                         AND o.order_date < CURRENT_DATE)
            FROM products p
            JOIN categories c ON c.category_id = p.category_id
            JOIN manufacturers m ON m.manufacturer_id = p.manufacturer_id
            WHERE p.product_id = %s
        """, (product_id,))
        row = cur.fetchone()
        if not row:
            return None
        (pid, name, cat, man, subcat, image, descr, comp, price, total_qty, orders_last) = row
        discount = 25 if orders_last == 0 else 0
        final_price = round(float(price) * (100 - discount) / 100, 2)
        return Product(pid, name, cat, man, subcat, image, descr, comp,
                       float(price), int(total_qty), float(price), final_price, discount)
    finally:
        release_connection(conn)


def get_sizes_for_product(product_id):
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT si.stock_item_id, sz.size_value, si.quantity_available
            FROM stock_items si
            JOIN sizes sz ON sz.size_id = si.size_id
            WHERE si.product_id = %s
            ORDER BY CAST(sz.size_value AS NUMERIC)
        """, (product_id,))
        return cur.fetchall()
    finally:
        release_connection(conn)


def list_categories():
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT category_id, category_name FROM categories ORDER BY category_name")
        return cur.fetchall()
    finally:
        release_connection(conn)


def search_products(query, limit=20):
    """Поиск товаров для формы ручного создания заказа."""
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT p.product_id, p.product_name, m.manufacturer_name, p.price
            FROM products p
            JOIN manufacturers m ON m.manufacturer_id = p.manufacturer_id
            WHERE LOWER(p.product_name) LIKE %s
            ORDER BY p.product_name
            LIMIT %s
        """, (f'%{query.lower()}%', limit))
        return cur.fetchall()
    finally:
        release_connection(conn)

                                                              stock.py
"""Работа со складом."""
from db.connection import get_connection, release_connection


def get_stock_item(stock_item_id):
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT si.stock_item_id, si.product_id, si.size_id, si.quantity_available,
                   p.product_name, p.price, m.manufacturer_name, sz.size_value
            FROM stock_items si
            JOIN products p ON p.product_id = si.product_id
            JOIN manufacturers m ON m.manufacturer_id = p.manufacturer_id
            JOIN sizes sz ON sz.size_id = si.size_id
            WHERE si.stock_item_id = %s
        """, (stock_item_id,))
        return cur.fetchone()
    finally:
        release_connection(conn)


def decrease_quantity(cur, stock_item_id, amount):
    cur.execute("""
        UPDATE stock_items
        SET quantity_available = quantity_available - %s
        WHERE stock_item_id = %s AND quantity_available >= %s
        RETURNING quantity_available
    """, (amount, stock_item_id, amount))
    if cur.fetchone() is None:
        raise ValueError('Недостаточно товара на складе')


def increase_quantity(cur, stock_item_id, amount):
    cur.execute("""
        UPDATE stock_items
        SET quantity_available = quantity_available + %s
        WHERE stock_item_id = %s
    """, (amount, stock_item_id))

                                                            user.py
"""Работа с пользователями."""
from db.connection import get_connection, release_connection


class User:
    def __init__(self, user_id, last_name, first_name, middle_name, login, role_name):
        self.user_id = user_id
        self.last_name = last_name
        self.first_name = first_name
        self.middle_name = middle_name or ''
        self.login = login
        self.role_name = role_name

    @property
    def full_name(self):
        return f'{self.last_name} {self.first_name} {self.middle_name}'.strip()

    @property
    def is_admin(self):
        return self.role_name == 'Администратор'

    @property
    def is_manager(self):
        return self.role_name == 'Менеджер'

    @property
    def can_manage_orders(self):
        return self.role_name in ('Администратор', 'Менеджер')


def find_by_login(login):
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT u.user_id, u.last_name, u.first_name, u.middle_name, u.login, r.role_name
            FROM users u
            JOIN roles r ON r.role_id = u.role_id
            WHERE u.login = %s
        """, (login,))
        row = cur.fetchone()
        return User(*row) if row else None
    finally:
        release_connection(conn)


def list_all():
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT u.user_id, u.last_name, u.first_name, u.middle_name, u.login, r.role_name
            FROM users u
            JOIN roles r ON r.role_id = u.role_id
            ORDER BY u.last_name
        """)
        return [User(*row) for row in cur.fetchall()]
    finally:
        release_connection(conn)


                                                                   tests/
                                                                   test_discount.py
"""Тесты для controllers/discount.py (с моками БД)."""
import sys
import os
import unittest
from unittest.mock import patch, MagicMock
from datetime import date

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from controllers import discount


class TestPreviousMonthRange(unittest.TestCase):

    @patch('controllers.discount.datetime')
    def test_range(self, mock_dt):
        mock_dt.now.return_value.date.return_value = date(2026, 10, 8)
        start, end = discount.get_previous_month_range()
        self.assertEqual(start, date(2026, 9, 1))
        self.assertEqual(end, date(2026, 10, 1))

    @patch('controllers.discount.datetime')
    def test_range_january(self, mock_dt):
        mock_dt.now.return_value.date.return_value = date(2026, 1, 15)
        start, end = discount.get_previous_month_range()
        self.assertEqual(start, date(2025, 12, 1))
        self.assertEqual(end, date(2026, 1, 1))


class TestCalculateFinalPrice(unittest.TestCase):

    @patch('controllers.discount.has_orders_last_month', return_value=True)
    def test_no_discount_when_orders_exist(self, mock_has):
        final, pct = discount.calculate_final_price(1, 1000.0)
        self.assertEqual(final, 1000.0)
        self.assertEqual(pct, 0)

    @patch('controllers.discount.has_orders_last_month', return_value=False)
    def test_discount_25_percent(self, mock_has):
        final, pct = discount.calculate_final_price(1, 1000.0)
        self.assertEqual(final, 750.0)
        self.assertEqual(pct, 25)

    @patch('controllers.discount.has_orders_last_month', return_value=False)
    def test_discount_rounding(self, mock_has):
        final, pct = discount.calculate_final_price(1, 999.99)
        self.assertEqual(final, 749.99)
        self.assertEqual(pct, 25)

    @patch('controllers.discount.has_orders_last_month', return_value=False)
    def test_discount_zero_price(self, mock_has):
        final, pct = discount.calculate_final_price(1, 0)
        self.assertEqual(final, 0)
        self.assertEqual(pct, 25)


if __name__ == '__main__':
    unittest.main()

                                                test_validstors.py
"""Тесты для utils/validators.py."""
import sys
import os
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils.validators import is_positive_int, validate_quantity


class TestIsPositiveInt(unittest.TestCase):

    def test_positive(self):
        self.assertTrue(is_positive_int('5'))
        self.assertTrue(is_positive_int(10))
        self.assertTrue(is_positive_int('1'))

    def test_zero(self):
        self.assertFalse(is_positive_int('0'))
        self.assertFalse(is_positive_int(0))

    def test_negative(self):
        self.assertFalse(is_positive_int('-3'))
        self.assertFalse(is_positive_int(-1))

    def test_not_a_number(self):
        self.assertFalse(is_positive_int('abc'))
        self.assertFalse(is_positive_int(''))
        self.assertFalse(is_positive_int(None))

    def test_float_string(self):
        self.assertFalse(is_positive_int('3.5'))


class TestValidateQuantity(unittest.TestCase):

    def test_valid(self):
        ok, msg = validate_quantity('5', 10)
        self.assertTrue(ok)
        self.assertEqual(msg, '')

    def test_empty(self):
        ok, msg = validate_quantity('', 10)
        self.assertFalse(ok)
        self.assertIn('Введите', msg)

    def test_not_int(self):
        ok, msg = validate_quantity('abc', 10)
        self.assertFalse(ok)
        self.assertIn('целым', msg)

    def test_zero(self):
        ok, msg = validate_quantity('0', 10)
        self.assertFalse(ok)
        self.assertIn('положительным', msg)

    def test_negative(self):
        ok, msg = validate_quantity('-2', 10)
        self.assertFalse(ok)

    def test_exceeds_max(self):
        ok, msg = validate_quantity('15', 10)
        self.assertFalse(ok)
        self.assertIn('10', msg)

    def test_exactly_max(self):
        ok, msg = validate_quantity('10', 10)
        self.assertTrue(ok)


if __name__ == '__main__':
    unittest.main()


                                                         utils/
                                                       messages.py
"""Диалоги сообщений."""
from PyQt5.QtWidgets import QMessageBox


def show_info(parent, text, title='Информация'):
    box = QMessageBox(parent)
    box.setIcon(QMessageBox.Information)
    box.setWindowTitle(title)
    box.setText(text)
    box.exec_()


def show_warning(parent, text, title='Предупреждение'):
    box = QMessageBox(parent)
    box.setIcon(QMessageBox.Warning)
    box.setWindowTitle(title)
    box.setText(text)
    box.exec_()


def show_error(parent, text, title='Ошибка'):
    box = QMessageBox(parent)
    box.setIcon(QMessageBox.Critical)
    box.setWindowTitle(title)
    box.setText(text)
    box.exec_()


def ask_confirmation(parent, text, title='Подтверждение'):
    box = QMessageBox(parent)
    box.setIcon(QMessageBox.Question)
    box.setWindowTitle(title)
    box.setText(text)
    box.setStandardButtons(QMessageBox.Yes | QMessageBox.No)
    box.setDefaultButton(QMessageBox.No)
    return box.exec_() == QMessageBox.Yes


                                                       validators.py
"""Валидация ввода."""


def is_positive_int(value):
    try:
        n = int(value)
        return n > 0
    except (TypeError, ValueError):
        return False


def validate_quantity(value, max_available):
    if not value:
        return False, 'Введите количество'
    try:
        n = int(value)
    except ValueError:
        return False, 'Количество должно быть целым числом'
    if n <= 0:
        return False, 'Количество должно быть положительным'
    if n > max_available:
        return False, f'Доступно не более {max_available} шт.'
    return True, ''

                                                             views/
                                                          cart_view.py
"""Корзина и оформление заказа."""
from PyQt5.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel,
                             QPushButton, QTableWidget, QTableWidgetItem,
                             QDialogButtonBox, QHeaderView, QWidget)
from PyQt5.QtCore import Qt, pyqtSignal

from controllers import order_controller
from controllers.auth_controller import current_user
from utils import messages


class CartView(QDialog):
    order_placed = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle('Чудо Обувь — Корзина')
        self.resize(700, 480)
        self.cart = []
        self._build_ui()
        self._refresh()

    def _build_ui(self):
        main = QVBoxLayout(self)

        self.table = QTableWidget(0, 5)
        self.table.setHorizontalHeaderLabels(
            ['Товар', 'Размер', 'Кол-во', 'Цена', 'Сумма']
        )
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        main.addWidget(self.table)

        self.total_label = QLabel('Итого: 0.00 ₽')
        self.total_label.setStyleSheet('font-size: 16px; font-weight: bold; color: #2c3e50;')
        self.total_label.setAlignment(Qt.AlignRight)
        main.addWidget(self.total_label)

        btns = QHBoxLayout()
        self.remove_btn = QPushButton('Удалить позицию')
        self.remove_btn.clicked.connect(self._remove_selected)
        btns.addWidget(self.remove_btn)
        btns.addStretch()

        self.checkout_btn = QPushButton('Оформить заказ')
        self.checkout_btn.setStyleSheet("""
            QPushButton { background-color: #27ae60; color: white;
                          padding: 8px 20px; border-radius: 6px; }
            QPushButton:hover { background-color: #219150; }
        """)
        self.checkout_btn.clicked.connect(self._checkout)
        btns.addWidget(self.checkout_btn)

        close_box = QDialogButtonBox(QDialogButtonBox.Close)
        close_box.rejected.connect(self.reject)
        btns.addWidget(close_box)

        main.addLayout(btns)

    def set_cart(self, cart):
        self.cart = cart
        self._refresh()

    def _refresh(self):
        self.table.setRowCount(0)
        total = 0
        for item in self.cart:
            row = self.table.rowCount()
            self.table.insertRow(row)
            self.table.setItem(row, 0, QTableWidgetItem(
                f'{item["manufacturer"]} | {item["name"]}'))
            self.table.setItem(row, 1, QTableWidgetItem(str(item['size'])))
            self.table.setItem(row, 2, QTableWidgetItem(str(item['quantity'])))
            self.table.setItem(row, 3, QTableWidgetItem(f'{item["price"]:.2f}'))
            subtotal = item['quantity'] * item['price']
            self.table.setItem(row, 4, QTableWidgetItem(f'{subtotal:.2f}'))
            total += subtotal
        self.total_label.setText(f'Итого: {total:.2f} ₽')

    def _remove_selected(self):
        row = self.table.currentRow()
        if row < 0:
            messages.show_warning(self, 'Выберите позицию для удаления')
            return
        del self.cart[row]
        self._refresh()

    def _checkout(self):
        if not self.cart:
            messages.show_warning(self, 'Корзина пуста')
            return
        user = current_user()
        if not user:
            messages.show_error(self, 'Требуется авторизация')
            return

        items = [{'stock_item_id': it['stock_item_id'], 'quantity': it['quantity']}
                 for it in self.cart]
        try:
            order_id = order_controller.place_order(user.user_id, items)
        except Exception as e:
            messages.show_error(self, f'Не удалось оформить заказ:\n{e}')
            return

        messages.show_info(self, f'Заказ №{order_id} успешно оформлен!')
        self.cart.clear()
        self._refresh()
        self.order_placed.emit()
        self.accept()

                                                 catalog_view.py
"""Каталог товаров."""
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QLineEdit,
                             QComboBox, QScrollArea, QFrame, QLabel,
                             QSizePolicy)
from PyQt5.QtCore import Qt, pyqtSignal
from PyQt5.QtGui import QPixmap

from controllers import catalog_controller

import os


RES_IMG_DIR = 'resources/images'


class ProductCard(QFrame):
    clicked = pyqtSignal(int)

    def __init__(self, product):
        super().__init__()
        self.product = product
        self.setFrameShape(QFrame.StyledPanel)
        self.setCursor(Qt.PointingHandCursor)

        if product.is_low_stock:
            self.setStyleSheet("""
                ProductCard {
                    background-color: #ffe0e0;
                    border: 1px solid #e0b0b0;
                    border-radius: 8px;
                }
            """)
        else:
            self.setStyleSheet("""
                ProductCard {
                    background-color: #ffffff;
                    border: 1px solid #dddddd;
                    border-radius: 8px;
                }
                ProductCard:hover {
                    border: 1px solid #3498db;
                }
            """)

        self._build_ui()

    def _build_ui(self):
        layout = QHBoxLayout(self)
        layout.setContentsMargins(12, 12, 12, 12)

        # Изображение
        img_label = QLabel()
        img_label.setFixedSize(140, 110)
        img_label.setStyleSheet('background: #fafafa; border-radius: 6px;')
        img_label.setAlignment(Qt.AlignCenter)

        img_path = None
        if self.product.image_path:
            candidate = os.path.join(RES_IMG_DIR, self.product.image_path)
            if os.path.exists(candidate):
                img_path = candidate
        if not img_path:
            candidate = os.path.join(RES_IMG_DIR, 'picture.png')
            if os.path.exists(candidate):
                img_path = candidate

        if img_path:
            pix = QPixmap(img_path)
            if not pix.isNull():
                img_label.setPixmap(pix.scaled(140, 110, Qt.KeepAspectRatio,
                                                Qt.SmoothTransformation))
        layout.addWidget(img_label)

        # Информация
        info = QVBoxLayout()

        title_row = QHBoxLayout()
        title = QLabel(f'{self.product.manufacturer_name} | {self.product.product_name}')
        title.setStyleSheet('font-size: 15px; font-weight: bold; color: #2c3e50;')
        title_row.addWidget(title)
        title_row.addStretch()

        price_text = f'{self.product.final_price:.2f} ₽'
        if self.product.discount_percent:
            price_text += f'  (скидка {self.product.discount_percent}%)'
        price = QLabel(price_text)
        price.setStyleSheet('font-size: 15px; font-weight: bold; color: #27ae60;')
        title_row.addWidget(price)
        info.addLayout(title_row)

        cat = QLabel(f'Категория: {self.product.category_name}')
        cat.setStyleSheet('color: #555;')
        info.addWidget(cat)

        qty = QLabel(f'Количество: {self.product.availability} ({self.product.total_quantity})')
        qty.setStyleSheet('color: #555;')
        info.addWidget(qty)

        comp = QLabel(f'Состав: {self.product.composition}')
        comp.setWordWrap(True)
        comp.setStyleSheet('color: #777; font-size: 12px;')
        info.addWidget(comp)

        layout.addLayout(info, 1)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.setMinimumHeight(140)

    def mousePressEvent(self, event):
        self.clicked.emit(self.product.product_id)


class CatalogView(QWidget):
    product_selected = pyqtSignal(int)

    def __init__(self):
        super().__init__()
        self._build_ui()
        self.reload()

    def _build_ui(self):
        main = QVBoxLayout(self)
        main.setContentsMargins(16, 16, 16, 16)

        # Фильтры
        filters = QHBoxLayout()
        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText('🔍 Поиск по названию и описанию')
        self.search_input.textChanged.connect(self._on_filter_changed)
        filters.addWidget(self.search_input, 2)

        self.category_combo = QComboBox()
        self.category_combo.currentIndexChanged.connect(self._on_filter_changed)
        filters.addWidget(self.category_combo, 1)

        self.sort_combo = QComboBox()
        self.sort_combo.addItem('Без сортировки', '')
        self.sort_combo.addItem('Цена ↑', 'price_asc')
        self.sort_combo.addItem('Цена ↓', 'price_desc')
        self.sort_combo.currentIndexChanged.connect(self._on_filter_changed)
        filters.addWidget(self.sort_combo, 1)

        main.addLayout(filters)

        # Список товаров
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setStyleSheet('QScrollArea { border: none; }')

        self.list_widget = QWidget()
        self.list_layout = QVBoxLayout(self.list_widget)
        self.list_layout.setAlignment(Qt.AlignTop)
        self.scroll.setWidget(self.list_widget)
        main.addWidget(self.scroll)

    def _load_categories(self):
        self.category_combo.blockSignals(True)
        self.category_combo.clear()
        self.category_combo.addItem('Все категории', None)
        for cat_id, cat_name in catalog_controller.get_all_categories():
            self.category_combo.addItem(cat_name, cat_id)
        self.category_combo.blockSignals(False)

    def _on_filter_changed(self):
        self.reload()

    def reload(self):
        # Очистка
        while self.list_layout.count():
            item = self.list_layout.takeAt(0)
            widget = item.widget()
            if widget:
                widget.deleteLater()

        # Загрузка категорий при первом вызове
        if self.category_combo.count() == 0:
            self._load_categories()

        # Параметры
        category_id = self.category_combo.currentData()
        search = self.search_input.text()
        sort = self.sort_combo.currentData()

        # Получение товаров
        try:
            products = catalog_controller.get_catalog(
                category_id=category_id, search=search, sort=sort
            )
        except Exception as e:
            err = QLabel(f'Ошибка загрузки каталога: {e}')
            err.setAlignment(Qt.AlignCenter)
            err.setStyleSheet('color: #c0392b; font-size: 14px; padding: 40px;')
            self.list_layout.addWidget(err)
            return

        if not products:
            empty = QLabel('Товары не найдены')
            empty.setAlignment(Qt.AlignCenter)
            empty.setStyleSheet('color: #888; font-size: 16px; padding: 40px;')
            self.list_layout.addWidget(empty)
            return

        for product in products:
            card = ProductCard(product)
            card.clicked.connect(self.product_selected.emit)
            self.list_layout.addWidget(card)


                                                    login_window.py
"""Окно авторизации."""
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QLabel, QLineEdit,
                             QPushButton, QHBoxLayout)
from PyQt5.QtCore import Qt, pyqtSignal
from PyQt5.QtGui import QPixmap, QIcon

from controllers import auth_controller
from utils import messages


class LoginWindow(QWidget):
    login_success = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.setWindowTitle('Чудо Обувь — Вход в систему')
        self.setWindowIcon(QIcon('resources/images/icon.png'))
        self.setFixedSize(420, 320)
        self._build_ui()

    def _build_ui(self):
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)

        logo = QLabel()
        pix = QPixmap('resources/images/logo.png')
        if not pix.isNull():
            logo.setPixmap(pix.scaled(120, 120, Qt.KeepAspectRatio,
                                       Qt.SmoothTransformation))
        logo.setAlignment(Qt.AlignCenter)
        layout.addWidget(logo)

        title = QLabel('Чудо Обувь')
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet('font-size: 22px; font-weight: bold; color: #2c3e50;')
        layout.addWidget(title)

        subtitle = QLabel('Вход в систему (пароль не требуется)')
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setStyleSheet('color: #666; margin-bottom: 10px;')
        layout.addWidget(subtitle)

        self.login_input = QLineEdit()
        self.login_input.setPlaceholderText('Введите логин, например isivanov')
        self.login_input.setStyleSheet('padding: 8px; font-size: 14px;')
        self.login_input.returnPressed.connect(self._on_login)
        layout.addWidget(self.login_input)

        btns = QHBoxLayout()
        btns.addStretch()
        self.login_btn = QPushButton('Войти')
        self.login_btn.setStyleSheet("""
            QPushButton {
                background-color: #3498db; color: white;
                padding: 8px 24px; border: none; border-radius: 6px;
                font-size: 14px;
            }
            QPushButton:hover { background-color: #2980b9; }
        """)
        self.login_btn.clicked.connect(self._on_login)
        btns.addWidget(self.login_btn)
        layout.addLayout(btns)

        hint = QLabel('Логины: isivanov, papetrov, asidorova, ...')
        hint.setStyleSheet('color: #888; font-size: 11px; margin-top: 10px;')
        hint.setAlignment(Qt.AlignCenter)
        layout.addWidget(hint)

        self.setLayout(layout)

    def _on_login(self):
        login = self.login_input.text().strip()
        if not login:
            messages.show_warning(self, 'Введите логин')
            return
        ok, result = auth_controller.login(login)
        if not ok:
            messages.show_error(self, result)
            return
        self.login_success.emit()

                                                              main_window.py
        """Главное окно приложения."""
from PyQt5.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
                             QPushButton, QLabel, QStackedWidget)
from PyQt5.QtGui import QIcon

from controllers.auth_controller import current_user, logout
from controllers import order_controller
from views.catalog_view import CatalogView
from views.product_view import ProductView
from views.cart_view import CartView
from views.orders_view import OrdersView
from views.order_edit_view import OrderEditView
from utils import messages


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle('Чудо Обувь — Система оформления заказов')
        self.setWindowIcon(QIcon('resources/images/icon.png'))
        self.resize(1100, 720)

        self.cart = []

        self._build_ui()
        self._refresh_header()
        self.catalog_view.reload()

    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        main = QVBoxLayout(central)
        main.setContentsMargins(0, 0, 0, 0)
        main.setSpacing(0)

        # Шапка
        self.header = QWidget()
        self.header.setStyleSheet('background-color: #2c3e50;')
        header_layout = QHBoxLayout(self.header)
        header_layout.setContentsMargins(16, 10, 16, 10)

        logo = QLabel('👟 Чудо Обувь')
        logo.setStyleSheet('color: white; font-size: 18px; font-weight: bold;')
        header_layout.addWidget(logo)
        header_layout.addStretch()

        self.user_label = QLabel('')
        self.user_label.setStyleSheet('color: white; font-size: 13px;')
        header_layout.addWidget(self.user_label)

        self.catalog_btn = QPushButton('Каталог')
        self.catalog_btn.setStyleSheet(self._header_btn_style())
        self.catalog_btn.clicked.connect(lambda: self.stack.setCurrentIndex(0))
        header_layout.addWidget(self.catalog_btn)

        self.cart_btn = QPushButton('🛒 Корзина (0)')
        self.cart_btn.setStyleSheet(self._header_btn_style())
        self.cart_btn.clicked.connect(self._open_cart)
        header_layout.addWidget(self.cart_btn)

        self.orders_btn = QPushButton('📋 Заказы')
        self.orders_btn.setStyleSheet(self._header_btn_style())
        self.orders_btn.clicked.connect(self._open_orders)
        header_layout.addWidget(self.orders_btn)

        self.logout_btn = QPushButton('Выйти')
        self.logout_btn.setStyleSheet(self._header_btn_style())
        self.logout_btn.clicked.connect(self._logout)
        header_layout.addWidget(self.logout_btn)

        main.addWidget(self.header)

        # Стек страниц
        self.stack = QStackedWidget()
        main.addWidget(self.stack)

        # Каталог
        self.catalog_view = CatalogView()
        self.catalog_view.product_selected.connect(self._open_product)
        self.stack.addWidget(self.catalog_view)

        # Заказы
        self.orders_view = OrdersView()
        self.orders_view.open_order.connect(self._open_order)
        self.orders_view.create_order.connect(self._create_order)
        self.orders_view.delete_order.connect(self._delete_order)
        self.stack.addWidget(self.orders_view)

    def _header_btn_style(self):
        return """
            QPushButton {
                background-color: transparent; color: white;
                padding: 6px 12px; border: 1px solid #4a6076;
                border-radius: 6px; font-size: 13px;
            }
            QPushButton:hover { background-color: #3a5169; }
        """

    def _refresh_header(self):
        user = current_user()
        if user:
            self.user_label.setText(user.full_name)
            self.orders_btn.setVisible(user.can_manage_orders)
        else:
            self.user_label.setText('Гость')
            self.orders_btn.setVisible(False)
        self.cart_btn.setText(f'🛒 Корзина ({len(self.cart)})')

    def _open_product(self, product_id):
        dialog = ProductView(product_id, self)
        dialog.add_to_cart.connect(self._add_to_cart)
        dialog.exec_()

    def _add_to_cart(self, stock_item_id, quantity, product_id):
        from models.product import get_product, get_sizes_for_product
        product = get_product(product_id)
        if not product:
            return
        size_value = ''
        for sid, sval, sqty in get_sizes_for_product(product_id):
            if sid == stock_item_id:
                size_value = sval
                break
        self.cart.append({
            'stock_item_id': stock_item_id,
            'quantity': quantity,
            'name': product.product_name,
            'manufacturer': product.manufacturer_name,
            'size': size_value,
            'price': product.final_price,
            'product_id': product_id,
        })
        self._refresh_header()

    def _open_cart(self):
        dialog = CartView(self)
        dialog.set_cart(self.cart)
        dialog.order_placed.connect(self._on_order_placed)
        dialog.exec_()

    def _on_order_placed(self):
        self.cart.clear()
        self._refresh_header()
        self.catalog_view.reload()

    def _open_orders(self):
        if not current_user() or not current_user().can_manage_orders:
            messages.show_warning(self, 'Доступ запрещён')
            return
        self.orders_view.reload()
        self.stack.setCurrentIndex(1)

    def _open_order(self, order_id):
        dialog = OrderEditView(order_id, self)
        dialog.changed = self.orders_view.reload
        dialog.exec_()

    def _create_order(self):
        from views.order_create_view import OrderCreateView
        if not current_user() or not current_user().can_manage_orders:
            messages.show_warning(self, 'Доступ запрещён')
            return
        dialog = OrderCreateView(self)
        dialog.order_created.connect(lambda _: self.orders_view.reload())
        dialog.exec_()

    def _delete_order(self, order_id):
        if not messages.ask_confirmation(self, f'Удалить заказ №{order_id}? Действие необратимо.'):
            return
        try:
            order_controller.remove_order(order_id)
        except Exception as e:
            messages.show_error(self, f'Ошибка удаления: {e}')
            return
        messages.show_info(self, 'Заказ удалён')
        self.orders_view.reload()

    def _logout(self):
        if not messages.ask_confirmation(self, 'Выйти из системы?'):
            return
        logout()
        self.cart.clear()
        self.close()

                                                 order_create_view.py
"""Окно ручного создания заказа (Менеджер/Администратор)."""
from PyQt5.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QComboBox, QSpinBox, QDoubleSpinBox, QDateEdit, QTableWidget,
    QTableWidgetItem, QHeaderView, QDialogButtonBox, QLineEdit, QWidget
)
from PyQt5.QtCore import Qt, QDate, pyqtSignal

from models.user import list_all as list_all_users
from models.product import search_products, get_sizes_for_product
from controllers import order_controller
from utils import messages


class OrderCreateView(QDialog):
    """Диалог ручного создания заказа."""

    order_created = pyqtSignal(int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle('Чудо Обувь — Новый заказ')
        self.resize(900, 620)
        self.items = []
        self._build_ui()
        self._load_clients()

    def _build_ui(self):
        main = QVBoxLayout(self)

        # --- Шапка: клиент + дата ---
        top = QHBoxLayout()
        top.addWidget(QLabel('Клиент:'))
        self.client_combo = QComboBox()
        self.client_combo.setMinimumWidth(250)
        top.addWidget(self.client_combo)

        top.addWidget(QLabel('Дата заказа:'))
        self.date_edit = QDateEdit()
        self.date_edit.setCalendarPopup(True)
        self.date_edit.setDate(QDate.currentDate())
        top.addWidget(self.date_edit)

        top.addStretch()
        main.addLayout(top)

        # --- Блок добавления позиции ---
        add_box = QHBoxLayout()

        add_box.addWidget(QLabel('Поиск:'))
        self.product_input = QLineEdit()
        self.product_input.setPlaceholderText('Введите название товара...')
        self.product_input.textChanged.connect(self._on_product_search)
        add_box.addWidget(self.product_input, 2)

        add_box.addWidget(QLabel('Товар:'))
        self.product_combo = QComboBox()
        self.product_combo.setMinimumWidth(250)
        self.product_combo.currentIndexChanged.connect(self._on_product_selected)
        add_box.addWidget(self.product_combo, 2)

        main.addLayout(add_box)

        # --- Размер, количество, цена, кнопка добавления ---
        add_box2 = QHBoxLayout()
        add_box2.addWidget(QLabel('Размер:'))
        self.size_combo = QComboBox()
        add_box2.addWidget(self.size_combo)

        add_box2.addWidget(QLabel('Кол-во:'))
        self.qty_spin = QSpinBox()
        self.qty_spin.setMinimum(1)
        self.qty_spin.setMaximum(999)
        add_box2.addWidget(self.qty_spin)

        add_box2.addWidget(QLabel('Цена:'))
        self.price_spin = QDoubleSpinBox()
        self.price_spin.setMinimum(0)
        self.price_spin.setMaximum(999999)
        self.price_spin.setDecimals(2)
        add_box2.addWidget(self.price_spin)

        add_box2.addStretch()

        self.add_btn = QPushButton('Добавить позицию')
        self.add_btn.setStyleSheet("""
            QPushButton { background-color: #3498db; color: white;
                          padding: 6px 16px; border-radius: 6px; }
            QPushButton:hover { background-color: #2980b9; }
        """)
        self.add_btn.clicked.connect(self._on_add_item)
        add_box2.addWidget(self.add_btn)

        main.addLayout(add_box2)

        # --- Таблица позиций ---
        self.table = QTableWidget(0, 6)
        self.table.setHorizontalHeaderLabels(
            ['Товар', 'Производитель', 'Размер', 'Кол-во', 'Цена', 'Сумма']
        )
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        main.addWidget(self.table)

        # --- Итог ---
        self.total_label = QLabel('Итого: 0.00 ₽')
        self.total_label.setStyleSheet(
            'font-size: 16px; font-weight: bold; color: #2c3e50;'
        )
        self.total_label.setAlignment(Qt.AlignRight)
        main.addWidget(self.total_label)

        # --- Кнопки ---
        btns = QHBoxLayout()
        self.remove_btn = QPushButton('Удалить позицию')
        self.remove_btn.clicked.connect(self._on_remove_item)
        btns.addWidget(self.remove_btn)
        btns.addStretch()

        save_btn = QPushButton('Создать заказ')
        save_btn.setStyleSheet("""
            QPushButton { background-color: #27ae60; color: white;
                          padding: 8px 20px; border-radius: 6px; }
            QPushButton:hover { background-color: #219150; }
        """)
        save_btn.clicked.connect(self._on_save)
        btns.addWidget(save_btn)

        close_box = QDialogButtonBox(QDialogButtonBox.Close)
        close_box.rejected.connect(self.reject)
        btns.addWidget(close_box)

        main.addLayout(btns)

    def _load_clients(self):
        self.client_combo.clear()
        self.client_combo.addItem('— выберите клиента —', None)
        try:
            for user in list_all_users():
                self.client_combo.addItem(
                    f'{user.full_name} ({user.login})', user.user_id
                )
        except Exception as e:
            messages.show_error(self, f'Не удалось загрузить клиентов:\n{e}')

    def _on_product_search(self, text):
        self.product_combo.clear()
        self.size_combo.clear()
        if not text or len(text.strip()) < 2:
            return
        try:
            results = search_products(text.strip())
        except Exception:
            return
        for pid, name, manufacturer, price in results:
            self.product_combo.addItem(
                f'{manufacturer} | {name} — {price:.2f} ₽',
                (pid, float(price))
            )

    def _on_product_selected(self, index):
        self.size_combo.clear()
        data = self.product_combo.currentData()
        if not data:
            return
        product_id, price = data
        self.price_spin.setValue(price)
        try:
            sizes = get_sizes_for_product(product_id)
        except Exception:
            return
        for stock_id, size_value, qty in sizes:
            if qty > 0:
                self.size_combo.addItem(
                    f'{size_value} ({qty} шт.)', (stock_id, qty)
                )

    def _on_add_item(self):
        product_data = self.product_combo.currentData()
        size_data = self.size_combo.currentData()

        if not product_data:
            messages.show_warning(self, 'Выберите товар')
            return
        if not size_data:
            messages.show_warning(
                self, 'Выберите размер (или товар отсутствует на складе)'
            )
            return

        product_id, _ = product_data
        stock_id, max_qty = size_data
        qty = self.qty_spin.value()
        price = self.price_spin.value()

        if qty <= 0 or qty > max_qty:
            messages.show_error(self, f'Количество должно быть от 1 до {max_qty}')
            return
        if price <= 0:
            messages.show_error(self, 'Цена должна быть больше нуля')
            return

        for item in self.items:
            if item['stock_item_id'] == stock_id:
                new_qty = item['quantity'] + qty
                if new_qty > max_qty:
                    messages.show_error(
                        self,
                        f'Суммарное количество превышает остаток ({max_qty} шт.)'
                    )
                    return
                item['quantity'] = new_qty
                self._refresh_table()
                return

        text = self.product_combo.currentText()
        parts = text.split('|')
        manufacturer = parts[0].strip() if len(parts) > 1 else ''
        name_part = parts[1].split('—')[0].strip() if len(parts) > 1 else text

        size_text = self.size_combo.currentText().split('(')[0].strip()

        self.items.append({
            'stock_item_id': stock_id,
            'quantity': qty,
            'price': price,
            'name': name_part,
            'manufacturer': manufacturer,
            'size': size_text,
        })
        self._refresh_table()

    def _on_remove_item(self):
        row = self.table.currentRow()
        if row < 0:
            messages.show_warning(self, 'Выберите позицию для удаления')
            return
        del self.items[row]
        self._refresh_table()

    def _refresh_table(self):
        self.table.setRowCount(0)
        total = 0.0
        for item in self.items:
            row = self.table.rowCount()
            self.table.insertRow(row)
            self.table.setItem(row, 0, QTableWidgetItem(item['name']))
            self.table.setItem(row, 1, QTableWidgetItem(item['manufacturer']))
            self.table.setItem(row, 2, QTableWidgetItem(str(item['size'])))
            self.table.setItem(row, 3, QTableWidgetItem(str(item['quantity'])))
            self.table.setItem(row, 4, QTableWidgetItem(f'{item["price"]:.2f}'))
            subtotal = item['quantity'] * item['price']
            self.table.setItem(row, 5, QTableWidgetItem(f'{subtotal:.2f}'))
            total += subtotal
        self.total_label.setText(f'Итого: {total:.2f} ₽')

    def _on_save(self):
        client_id = self.client_combo.currentData()
        if not client_id:
            messages.show_warning(self, 'Выберите клиента')
            return
        if not self.items:
            messages.show_warning(self, 'Добавьте хотя бы одну позицию')
            return

        order_date = self.date_edit.date().toString('yyyy-MM-dd')
        items_payload = [
            {
                'stock_item_id': it['stock_item_id'],
                'quantity': it['quantity'],
                'price': it['price'],
            }
            for it in self.items
        ]

        try:
            order_id = order_controller.place_manual_order(
                client_id, order_date, items_payload
            )
        except Exception as e:
            messages.show_error(self, f'Не удалось создать заказ:\n{e}')
            return

        messages.show_info(self, f'Заказ №{order_id} успешно создан!')
        self.order_created.emit(order_id)
        self.accept()

                                                           order_edit_view.py
"""Просмотр/редактирование заказа."""
from PyQt5.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel,
                             QTableWidget, QTableWidgetItem, QPushButton,
                             QDateEdit, QDialogButtonBox, QHeaderView)
from PyQt5.QtCore import Qt, QDate

from controllers import order_controller
from controllers.auth_controller import current_user
from utils import messages


class OrderEditView(QDialog):
    changed = None

    def __init__(self, order_id, parent=None):
        super().__init__(parent)
        self.order_id = order_id
        self.order = None
        self.is_admin = bool(current_user() and current_user().is_admin)
        self.setWindowTitle(f'Чудо Обувь — Заказ №{order_id}')
        self.resize(750, 520)
        self._build_ui()
        self._load()

    def _build_ui(self):
        main = QVBoxLayout(self)

        # Шапка
        top = QHBoxLayout()
        top.addWidget(QLabel('Дата заказа:'))
        self.date_edit = QDateEdit()
        self.date_edit.setCalendarPopup(True)
        self.date_edit.setEnabled(self.is_admin)
        top.addWidget(self.date_edit)
        top.addWidget(QLabel('Клиент:'))
        self.client_label = QLabel('')
        self.client_label.setStyleSheet('font-weight: bold;')
        top.addWidget(self.client_label)
        top.addStretch()
        main.addLayout(top)

        # Таблица позиций
        self.table = QTableWidget(0, 6)
        self.table.setHorizontalHeaderLabels(
            ['Товар', 'Произв.', 'Размер', 'Кол-во', 'Цена', 'Сумма']
        )
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.Stretch)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        main.addWidget(self.table)

        # Итог
        self.total_label = QLabel('')
        self.total_label.setStyleSheet('font-size: 16px; font-weight: bold;')
        self.total_label.setAlignment(Qt.AlignRight)
        main.addWidget(self.total_label)

        # Кнопки
        btns = QHBoxLayout()
        if self.is_admin:
            self.del_item_btn = QPushButton('Удалить позицию')
            self.del_item_btn.clicked.connect(self._remove_item)
            btns.addWidget(self.del_item_btn)
        btns.addStretch()

        if self.is_admin:
            save_btn = QPushButton('Сохранить изменения')
            save_btn.setStyleSheet("""
                QPushButton { background-color: #27ae60; color: white;
                              padding: 8px 20px; border-radius: 6px; }
            """)
            save_btn.clicked.connect(self._save)
            btns.addWidget(save_btn)

        close_box = QDialogButtonBox(QDialogButtonBox.Close)
        close_box.rejected.connect(self.reject)
        btns.addWidget(close_box)
        main.addLayout(btns)

        self.removed_items = []

    def _load(self):
        order = order_controller.get_order_details(self.order_id)
        if not order:
            messages.show_error(self, 'Заказ не найден')
            self.reject()
            return
        self.order = order
        self.client_label.setText(order.fio)
        self.date_edit.setDate(QDate.fromString(str(order.order_date), 'yyyy-MM-dd'))
        self._refresh_table()

    def _refresh_table(self):
        self.table.setRowCount(0)
        total = 0
        for it in self.order.items:
            item_id, qty, price, pname, mname, size = it
            row = self.table.rowCount()
            self.table.insertRow(row)
            self.table.setItem(row, 0, QTableWidgetItem(pname))
            self.table.setItem(row, 1, QTableWidgetItem(mname))
            self.table.setItem(row, 2, QTableWidgetItem(str(size)))
            self.table.setItem(row, 3, QTableWidgetItem(str(qty)))
            self.table.setItem(row, 4, QTableWidgetItem(f'{float(price):.2f}'))
            self.table.setItem(row, 5, QTableWidgetItem(f'{qty * float(price):.2f}'))
            total += qty * float(price)
        self.total_label.setText(f'Итого: {total:.2f} ₽')

    def _remove_item(self):
        row = self.table.currentRow()
        if row < 0:
            messages.show_warning(self, 'Выберите позицию')
            return
        if not messages.ask_confirmation(self, 'Удалить выбранную позицию из заказа?'):
            return
        item_id = self.order.items[row][0]
        self.removed_items.append(item_id)
        self.order.items = [it for it in self.order.items if it[0] != item_id]
        self._refresh_table()

    def _save(self):
        new_date = self.date_edit.date().toString('yyyy-MM-dd')
        try:
            order_controller.edit_order(self.order_id, new_date, self.removed_items)
        except Exception as e:
            messages.show_error(self, f'Ошибка сохранения: {e}')
            return
        messages.show_info(self, 'Изменения сохранены')
        if self.changed:
            self.changed()
        self.accept()

                                                       orders_view.py
"""Список заказов (Менеджер/Администратор)."""
from PyQt5.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton,
                             QTableWidget, QTableWidgetItem, QHeaderView,
                             QLabel)
from PyQt5.QtCore import Qt, pyqtSignal

from controllers import order_controller
from utils import messages


class OrdersView(QWidget):
    open_order = pyqtSignal(int)
    create_order = pyqtSignal()
    delete_order = pyqtSignal(int)

    def __init__(self):
        super().__init__()
        self._build_ui()

    def _build_ui(self):
        main = QVBoxLayout(self)
        main.setContentsMargins(16, 16, 16, 16)

        header = QHBoxLayout()
        title = QLabel('Список заказов')
        title.setStyleSheet('font-size: 18px; font-weight: bold; color: #2c3e50;')
        header.addWidget(title)
        header.addStretch()

        self.add_btn = QPushButton('+ Новый заказ')
        self.add_btn.setStyleSheet("""
            QPushButton { background-color: #3498db; color: white;
                          padding: 6px 16px; border-radius: 6px; }
            QPushButton:hover { background-color: #2980b9; }
        """)
        self.add_btn.clicked.connect(self.create_order.emit)
        header.addWidget(self.add_btn)

        self.refresh_btn = QPushButton('Обновить')
        self.refresh_btn.clicked.connect(self.reload)
        header.addWidget(self.refresh_btn)

        main.addLayout(header)

        self.table = QTableWidget(0, 4)
        self.table.setHorizontalHeaderLabels(['№', 'Дата', 'ФИО клиента', 'Действия'])
        self.table.horizontalHeader().setSectionResizeMode(2, QHeaderView.Stretch)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.table.cellDoubleClicked.connect(self._on_double_click)
        main.addWidget(self.table)

    def reload(self):
        self.table.setRowCount(0)
        try:
            orders = order_controller.get_all_orders()
        except Exception as e:
            messages.show_error(self, f'Ошибка загрузки заказов:\n{e}')
            return
        for order in orders:
            row = self.table.rowCount()
            self.table.insertRow(row)
            self.table.setItem(row, 0, QTableWidgetItem(str(order.order_id)))
            self.table.setItem(row, 1, QTableWidgetItem(str(order.order_date)))
            self.table.setItem(row, 2, QTableWidgetItem(order.fio))

            open_btn = QPushButton('Открыть')
            open_btn.clicked.connect(
                lambda _, oid=order.order_id: self.open_order.emit(oid))

            del_btn = QPushButton('Удалить')
            del_btn.setStyleSheet('background-color: #e74c3c; color: white;')
            del_btn.clicked.connect(
                lambda _, oid=order.order_id: self.delete_order.emit(oid))

            wrapper = QWidget()
            wl = QHBoxLayout(wrapper)
            wl.setContentsMargins(0, 0, 0, 0)
            wl.addWidget(open_btn)
            wl.addWidget(del_btn)
            self.table.setCellWidget(row, 3, wrapper)

    def _on_double_click(self, row, col):
        item = self.table.item(row, 0)
        if item:
            self.open_order.emit(int(item.text()))


                                                      product_view.py
"""Форма просмотра товара."""
from PyQt5.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel,
                             QPushButton, QSpinBox, QComboBox, QFrame,
                             QFormLayout, QDialogButtonBox)
from PyQt5.QtCore import Qt, pyqtSignal
from PyQt5.QtGui import QPixmap

from controllers import catalog_controller
from utils import messages
import os

RES_IMG_DIR = 'resources/images'


class ProductView(QDialog):
    add_to_cart = pyqtSignal(int, int, int)

    def __init__(self, product_id, parent=None):
        super().__init__(parent)
        self.product_id = product_id
        self.product = None
        self.sizes = []
        self.setWindowTitle('Чудо Обувь — Просмотр товара')
        self.resize(700, 560)
        self._build_ui()
        self._load_data()

    def _build_ui(self):
        main = QVBoxLayout(self)

        top = QHBoxLayout()

        self.img_label = QLabel()
        self.img_label.setFixedSize(220, 180)
        self.img_label.setStyleSheet('background: #fafafa; border-radius: 8px;')
        self.img_label.setAlignment(Qt.AlignCenter)
        top.addWidget(self.img_label)

        info = QFormLayout()
        self.title_label = QLabel()
        self.title_label.setStyleSheet('font-size: 18px; font-weight: bold; color: #2c3e50;')
        info.addRow(self.title_label)
        self.category_label = QLabel()
        info.addRow('Категория:', self.category_label)
        self.manufacturer_label = QLabel()
        info.addRow('Производство:', self.manufacturer_label)
        self.price_label = QLabel()
        self.price_label.setStyleSheet('font-size: 16px; font-weight: bold; color: #27ae60;')
        info.addRow('Цена со скидкой:', self.price_label)
        self.composition_label = QLabel()
        self.composition_label.setWordWrap(True)
        info.addRow('Состав:', self.composition_label)
        self.description_label = QLabel()
        self.description_label.setWordWrap(True)
        info.addRow('Описание:', self.description_label)

        top.addLayout(info, 1)
        main.addLayout(top)

        line = QFrame()
        line.setFrameShape(QFrame.HLine)
        line.setStyleSheet('color: #ddd;')
        main.addWidget(line)

        form = QHBoxLayout()
        form.addWidget(QLabel('Размер:'))
        self.size_combo = QComboBox()
        self.size_combo.currentIndexChanged.connect(self._on_size_changed)
        form.addWidget(self.size_combo)

        form.addWidget(QLabel('Количество:'))
        self.qty_spin = QSpinBox()
        self.qty_spin.setMinimum(1)
        self.qty_spin.setMaximum(1)
        form.addWidget(self.qty_spin)

        self.available_label = QLabel('')
        self.available_label.setStyleSheet('color: #666;')
        form.addWidget(self.available_label)

        form.addStretch()
        self.add_btn = QPushButton('Добавить в корзину')
        self.add_btn.setStyleSheet("""
            QPushButton { background-color: #27ae60; color: white;
                          padding: 8px 20px; border-radius: 6px; }
            QPushButton:hover { background-color: #219150; }
        """)
        self.add_btn.clicked.connect(self._on_add)
        form.addWidget(self.add_btn)
        main.addLayout(form)

        buttons = QDialogButtonBox(QDialogButtonBox.Close)
        buttons.rejected.connect(self.reject)
        main.addWidget(buttons)

    def _load_data(self):
        product, sizes = catalog_controller.get_product_details(self.product_id)
        if not product:
            messages.show_error(self, 'Товар не найден')
            self.reject()
            return
        self.product = product
        self.sizes = sizes

        img_path = None
        if product.image_path:
            candidate = os.path.join(RES_IMG_DIR, product.image_path)
            if os.path.exists(candidate):
                img_path = candidate
        if not img_path:
            candidate = os.path.join(RES_IMG_DIR, 'picture.png')
            if os.path.exists(candidate):
                img_path = candidate
        if img_path:
            pix = QPixmap(img_path)
            if not pix.isNull():
                self.img_label.setPixmap(pix.scaled(220, 180, Qt.KeepAspectRatio,
                                                     Qt.SmoothTransformation))

        self.title_label.setText(f'{product.manufacturer_name} | {product.product_name}')
        self.category_label.setText(product.category_name)
        self.manufacturer_label.setText(product.manufacturer_name)

        price_text = f'{product.final_price:.2f} ₽'
        if product.discount_percent:
            price_text += f'  (скидка {product.discount_percent}%, было {product.base_price:.2f} ₽)'
        self.price_label.setText(price_text)

        self.composition_label.setText(product.composition)
        self.description_label.setText(product.description)

        self.size_combo.clear()
        for stock_id, size_value, qty in sizes:
            self.size_combo.addItem(f'{size_value} ({qty} шт.)', (stock_id, qty))
        self._on_size_changed()

    def _on_size_changed(self):
        data = self.size_combo.currentData()
        if data:
            stock_id, qty = data
            self.qty_spin.setMaximum(max(1, qty))
            self.qty_spin.setValue(1)
            self.available_label.setText(f'Доступно: {qty} шт.')

    def _on_add(self):
        data = self.size_combo.currentData()
        if not data:
            messages.show_warning(self, 'Выберите размер')
            return
        stock_id, qty = data
        if qty <= 0:
            messages.show_warning(self, 'Товар отсутствует на складе')
            return
        count = self.qty_spin.value()
        if count <= 0 or count > qty:
            messages.show_error(self, f'Количество должно быть от 1 до {qty}')
            return
        self.add_to_cart.emit(stock_id, count, self.product_id)
        messages.show_info(self, 'Товар добавлен в корзину')

                                                         main.py
"""
Точка входа в приложение «Чудо Обувь».
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PyQt5.QtWidgets import QApplication
from PyQt5.QtGui import QIcon

from db.connection import init_pool, close_all
from views.login_window import LoginWindow
from views.main_window import MainWindow
from utils import messages


def load_styles(app):
    path = 'resources/styles/style.qss'
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8') as f:
            app.setStyleSheet(f.read())


def main():
    app = QApplication(sys.argv)
    app.setApplicationName('Чудо Обувь')
    app.setWindowIcon(QIcon('resources/images/icon.png'))
    load_styles(app)

    try:
        init_pool()
    except Exception as e:
        messages.show_error(None, f'Не удалось подключиться к базе данных:\n{e}')
        sys.exit(1)

    login_window = LoginWindow()
    main_window_ref = {'window': None}

    def on_login_success():
        window = MainWindow()
        main_window_ref['window'] = window
        window.show()
        login_window.close()

    login_window.login_success.connect(on_login_success)
    login_window.show()

    exit_code = app.exec_()
    close_all()
    sys.exit(exit_code)


if __name__ == '__main__':
    main()


requirements.txt
    PyQt5==5.15.9
psycopg2-binary==2.9.9
openpyxl==3.1.2


