from google.cloud import secretmanager
import argparse
import pymysql
from pymysql.constants import CLIENT
import logging
import random
import time

logging.basicConfig(format='%(asctime)s %(message)s', level=logging.INFO)

class AssetDB():
    def __init__(self, host, user, password, db):
        self.connection = pymysql.connect(host=host, user=user, password=password, database=db, client_flag=CLIENT.MULTI_STATEMENTS)

    def execute(self, sql, args=None):
        with self.connection.cursor() as cursor:
            cursor.execute(sql, args)
        self.connection.commit()

    def executemany(self, sql, args):
        with self.connection.cursor() as cursor:
            cursor.executemany(sql, args)
        self.connection.commit()

    def init_db(self, symbols, min_user_id=2, max_user_id=100):
        with open("init.sqlt", "r") as fin:
            sql = fin.read()
        self.execute(sql)
        
        for i in range(min_user_id, max_user_id):
            sql = "insert into user_asset (user_id, token, balance) values (%s, %s, %s)"
            args = []
            for symbol in symbols:
                arg = (i, symbol, round(random.uniform(1.0, 100.0), 8))
                args.append(arg)
                # logging.info(f"Generating user_id: {i}, token: {symbol}")
            self.executemany(sql, args)
            
    def upsert(self, symbols, batch_size, max_user_id):
        sql = "insert into user_asset (user_id, token, balance) values (%s, %s, %s) on duplicate key update balance=values(balance)"
        n = 0
        while True:
            args = []
            for i in range(batch_size):
                user_id = random.randint(1, max_user_id)
                token = symbols[random.randint(1, len(symbols) - 1)]
                balance = round(random.uniform(1.0, 100.0), 8)
                args.append((user_id, token, balance))
            
            self.executemany(sql, args)
            n = n + 1
            if n % 100 == 0:
                logging.info(f"{batch_size * n} records upserted.")
            time.sleep(interval)
            
    def upsertfew(self, user_ids, tokens):
        sql = "insert into user_asset (user_id, token, balance) values (%s, %s, %s) on duplicate key update balance=values(balance)"
        n = 0
        while True:
            args = []
            for user_id in user_ids:
                for token in tokens:
                    balance = round(random.uniform(1.0, 100.0), 8)
                    args.append((user_id, token, balance))

            try:
                self.executemany(sql, args)
            except Exception as e:
                logging.error(e)
            n = n + 1
            if n % 10 == 0:
                logging.info(f"{len(user_ids) * len(tokens) * n} records upserted.")
            time.sleep(interval)        

def get_password(project_id, secret_id):
    client = secretmanager.SecretManagerServiceClient()
    response = client.access_secret_version(request={"name": f"projects/{project_id}/secrets/{secret_id}/versions/latest"})
    payload = response.payload.data.decode("UTF-8").strip()
    return payload

def get_symbols():
    with open("symbols.txt", "r") as fin:
        lines = fin.read()
        return lines.split("\n")
        
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', help='project id')
    parser.add_argument('--secret', help='secret id that contains db password')
    parser.add_argument('--db_host', help='db host ip or hostname')
    parser.add_argument('--db_user', help='db username')
    parser.add_argument('--db_password', help='db password')
    parser.add_argument('--db_schema', help='db schema')
    parser.add_argument('--init', action='store_true', help='init db')
    parser.add_argument('--upsertfew', action='store_true', help='upsert a few users')
    parser.add_argument('--user_ids', help='user ids to upsert, comma seperated')
    parser.add_argument('--tokens', help='tokens to upsert, comma seperated')
    parser.add_argument('--min_user_id', type=int, help='minimum user id')
    parser.add_argument('--max_user_id', type=int, help='maximum user id')
    parser.add_argument('--batch_size', type=int, help='batch size of each upsert sql')
    parser.add_argument('--interval', type=float, help='how many seconds to sleep between each batch')

    args = parser.parse_args()
    project_id = args.project
    secret_id = args.secret
    db_host = args.db_host
    db_user = args.db_user
    db_schema = args.db_schema
    min_user_id = args.min_user_id
    max_user_id = args.max_user_id
    batch_size = args.batch_size
    user_ids = args.user_ids
    tokens = args.tokens
    interval = args.interval
    db_password = get_password(project_id, secret_id)
    symbols = get_symbols()
    
    db = AssetDB(db_host, db_user, db_password, db_schema)
    db.execute("select 1")
    
    logging.info("Start generator")

    if args.init:
        logging.info("Initializing DB...")
        db.init_db(symbols, min_user_id, max_user_id)
        logging.info("DB initialized. Exit.")
        exit(0)
    
    if args.upsertfew:
        db.upsertfew(user_ids.split(","), tokens.split(","))
        exit(0)
    
    if args.upsert:
        db.upsert(symbols, batch_size, max_user_id)
        exit(0)