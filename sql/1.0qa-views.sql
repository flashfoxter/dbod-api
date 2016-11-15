------------------------------
-- VIEWS
------------------------------

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

-- Instance Attribute View
CREATE OR REPLACE VIEW apiato_ro.instance_attribute AS
SELECT instance_attribute.attribute_id AS id,
       instance_attribute.instance_id,
       instance_attribute.name,
       instance_attribute.value
FROM apiato.instance_attribute;

--Volume Attribute View
CREATE OR REPLACE VIEW apiato_ro.volume_attribute AS
SELECT volume_attribute.attribute_id AS id,
       volume_attribute.volume_id,
       volume_attribute.name,
       volume_attribute.value
FROM apiato.volume_attribute;

-- Volume View
CREATE OR REPLACE VIEW apiato_ro.volume AS
SELECT volume.volume_id AS id,
       volume.instance_id,
       apiato.volume_type.type AS type,
       volume.server,
       volume.mounting_path
FROM apiato.volume
  JOIN apiato.volume_type ON apiato.volume.volume_type_id = apiato.volume_type.volume_type_id;

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
    apiato.get_instance_attributes(CAST (apiato.instance.instance_id AS int)) attributes,
    apiato.get_instance_attribute('port', CAST (apiato.instance.instance_id AS int)) port,
    get_volumes volumes
  FROM apiato.instance
    JOIN apiato.instance_type ON apiato.instance.instance_type_id = apiato.instance_type.instance_type_id
    LEFT JOIN apiato.host ON apiato.instance.host_id = apiato.host.host_id,
    apiato.get_volumes(apiato.instance.instance_id);