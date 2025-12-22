import re
from typing import Dict
import pandas as pd
import json
from datetime import datetime
from functools import reduce
from copy import deepcopy


class Entry:
    def __init__(self, account_name, data: Dict) -> None:
        self.account = account_name
        self.date = data['תאריך'].to_pydatetime().strftime("%d-%m-%Y")
        self.description: str = data.get('תיאור', data.get('תאור'))
        self.category = data['קטגוריה'] if data['קטגוריה'] != 0 else ""
        try:
            self.reference = int(data['אסמכתא'])
        except ValueError:
            self.reference = 0
        income = float(data['זכות'])
        expense = float(data['חובה'])
        self.amount: float = income - expense
        self.balance = float(re.sub(r'[^1-9-.]', '', str(data['יתרה'])))


excel_path = "./Flow.xlsx"

sheets = pd.read_excel(excel_path, sheet_name=[0, 2])
sheets["Dima"] = sheets[0]
sheets["Anna"] = sheets[2]


def as_key(date_str: str):
    return datetime.strptime(date_str, '%d-%m-%Y').strftime("%y%m%d")


def min_date(f: str, s: str):
    return f if f < s else s


entries = []
num_of_columns = 9

for account in ["Dima", "Anna"]:
    df = sheets[account].fillna(0)
    df_columns = [str.strip(col) for col in df.columns[:num_of_columns]]
    print(df_columns)
    transactions_data = map(lambda entry_value: zip(df_columns, entry_value[:num_of_columns]), df.values.tolist())
    account_entries = [Entry(account, dict(data)) for data in transactions_data]
    print(f"account {account}: found {len(account_entries)} entries")
    entries.extend(account_entries)

date_keys = map(lambda e: as_key(e.date), entries)
min_reduce = reduce(min, deepcopy(date_keys))
max_reduce = reduce(max, deepcopy(date_keys))

filename = f"transactions_{min_reduce}_{max_reduce}.json"
with open(filename, "w", encoding='utf-8') as file:
    json.dump([e.__dict__ for e in entries], file, ensure_ascii=False)
print(filename)
