import datetime

from google.cloud import bigtable
from uuid import uuid4


def write_simple(cluster_name, project_id, instance_id, table_id):
    client = bigtable.Client(project=project_id, admin=True)
    instance = client.instance(instance_id)
    table = instance.table(table_id)

    timestamp = datetime.datetime.utcnow()
    column_family_id = "weka-cluster"

    row_key = f"weka-cluster-{cluster_name}"

    row = table.direct_row(row_key)
    row.set_cell(column_family_id, "ready", False, timestamp)
    row.commit()

    print("Successfully wrote row {}.".format(row_key))

