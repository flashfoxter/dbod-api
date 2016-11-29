------------------------------
-- VIEWS
------------------------------

--Host
CREATE OR REPLACE VIEW apiato_ro.host AS
SELECT host.host_id AS id,
       host.name,
       host.memory
FROM apiato.host;

-- Instance View
CREATE OR REPLACE VIEW apiato_ro.instance AS
SELECT instance.instance_id AS id,
       instance.owner AS username,
       instance.name,
       instance.e_group,
       instance.category "class",
       instance.creation_date,
       instance.expiry_date,
       instance_type.type AS type,
       instance.project,
       instance.description,
       instance_master.name AS master,
       instance_slave.name AS slave,
       host.name AS host,
       instance.state,
       instance.status
FROM apiato.instance
  LEFT JOIN apiato.instance AS instance_master ON apiato.instance.instance_id = instance_master.instance_id
  LEFT JOIN apiato.instance AS instance_slave ON apiato.instance.instance_id = instance_slave.instance_id
  JOIN apiato.instance_type ON apiato.instance.instance_type_id = apiato.instance_type.instance_type_id
  JOIN apiato.host ON apiato.instance.host_id = apiato.host.host_id;


CREATE OR REPLACE VIEW apiato_ro.cluster_attributes AS
SELECT
      apiato.cluster.cluster_id,
      apiato.get_cluster_attributes(apiato.cluster.cluster_id) as attributes
FROM apiato.cluster;

CREATE OR REPLACE VIEW apiato_ro.instance_attributes AS
SELECT
      apiato.instance.instance_id,
      apiato.get_instance_attributes(apiato.instance.instance_id) as attributes
FROM apiato.instance;

CREATE OR REPLACE VIEW apiato_ro.volume_attributes AS
SELECT
      apiato.volume.volume_id,
      apiato.get_volume_attributes(apiato.volume.volume_id) as attributes
FROM apiato.volume;

-- Volume View
CREATE OR REPLACE VIEW apiato_ro.volume AS
SELECT volume.volume_id AS id,
       volume.instance_id,
       volume.file_mode,
       volume.owner,
       volume."group",
       volume.mount_options,
       apiato.instance.name AS name,
       apiato.volume_type.type AS type,
       volume.server,
       volume.mounting_path,
       apiato.get_volume_attributes(apiato.volume.volume_id) as attributes
FROM apiato.volume
  JOIN apiato.volume_type ON apiato.volume.volume_type_id = apiato.volume_type.volume_type_id
  JOIN apiato.instance ON apiato.volume.instance_id = apiato.instance.instance_id;

-- Metadata View
CREATE OR REPLACE VIEW apiato_ro.metadata AS
  SELECT
    instance.instance_id AS id,
    instance.owner AS username,
    instance.name AS db_name,
    instance.category "class",
    instance_type.type AS type,
    instance.version,
    string_to_array(host.name::text, ','::text) as hosts,
    apiato.get_instance_attributes(apiato.instance.instance_id) attributes,
    apiato.get_instance_attribute('port', apiato.instance.instance_id ) port,
    get_volumes volumes,
    instance.cluster_id
  FROM apiato.instance
    JOIN apiato.instance_type ON apiato.instance.instance_type_id = apiato.instance_type.instance_type_id
    LEFT JOIN apiato.host ON apiato.instance.host_id = apiato.host.host_id,
    apiato.get_volumes(apiato.instance.instance_id);


-- cluster View
CREATE OR REPLACE VIEW apiato_ro.cluster AS
  SELECT
    cluster.cluster_id AS id,
    cluster.owner AS username,
    cluster.name AS name,
    cluster.e_group,
    cluster.project,
    cluster.description,
    cluster.category "class",
    instance_type.type AS type,
    cluster.version,
    cluster_master.name AS master_name,
    get_cluster_instances as instances,
    apiato.get_cluster_attributes(apiato.cluster.cluster_id) as attributes,
    apiato.get_cluster_attribute('port', apiato.cluster.cluster_id ) port
  FROM apiato.cluster
    JOIN apiato.instance_type ON apiato.cluster.instance_type_id = apiato.instance_type.instance_type_id
    LEFT JOIN apiato.cluster AS cluster_master ON apiato.cluster.cluster_id = cluster_master.master_cluster_id,
      apiato.get_cluster_instances(apiato.cluster.cluster_id);


-- Functional Aliases View
CREATE OR REPLACE VIEW apiato_ro.functional_alias AS
  SELECT functional_alias.functional_alias_id AS id,
         apiato.instance.instance_id,
         functional_alias.dns_name,
         apiato.instance.name AS name,
         functional_alias.alias
  FROM apiato.functional_alias
  LEFT JOIN apiato.instance ON apiato.functional_alias.instance_id = apiato.instance.instance_id ;

-- Rundeck instances View
CREATE OR REPLACE VIEW apiato_ro.rundeck_instance AS
  SELECT apiato.instance.name AS db_name,
         apiato.functional_alias.alias AS hostname,
         apiato.get_instance_attribute('port', apiato.instance.instance_id) AS port,
         'dbod'::CHAR(4) AS username,
         apiato.instance_type.type AS db_type,
         apiato.instance.category AS category,
         apiato.instance_type.type || ',' || category AS tags
  FROM apiato.instance
    JOIN apiato.functional_alias ON apiato.instance.instance_id = apiato.functional_alias.instance_id
    JOIN apiato.instance_type ON apiato.instance.instance_type_id = apiato.instance_type.instance_type_id;

-- Host aliases View
CREATE OR REPLACE VIEW apiato_ro.host_alias AS
  SELECT host.name AS host,
         array_agg('dbod-' || regexp_replace(apiato.instance.name, '_', '-', 'g') || '.cern.ch') AS aliases
  FROM apiato.instance
    JOIN apiato.host ON apiato.instance.host_id = apiato.host.host_id
  GROUP BY host;
