-- Copyright (C) 2017, CERN
-- This software is distributed under the terms of the GNU General Public
-- Licence version 3 (GPL Version 3), copied verbatim in the file "COPYING".
-- In applying this license, CERN does not waive the privileges and immunities
-- granted to it by virtue of its status as Intergovernmental Organization
-- or submit itself to any jurisdiction.

CREATE SCHEMA IF NOT EXISTS public;

------------------------------------------
-- TYPES
------------------------------------------
CREATE TYPE public.instance_state AS ENUM (
  'RUNNING',
  'MAINTENANCE',
  'AWAITING_APPROVAL',
  'JOB_PENDING',
  'STOPPED',
  'BUSY'
);

CREATE TYPE public.instance_status AS ENUM (
  'ACTIVE',
  'NON_ACTIVE'
);

CREATE TYPE public.instance_category AS ENUM (
  'PROD',
  'DEV',
  'TEST',
  'QA',
  'REF'
);

CREATE TYPE public.job_state AS ENUM (
  'FINISHED_FAIL',
  'FINISHED_OK'
);

-- INSTANCE_TYPE
CREATE TABLE public.instance_type (
  id serial,
  type             varchar(64) UNIQUE NOT NULL,
  description      varchar(1024),
  CONSTRAINT instance_type_pkey PRIMARY KEY (id)
);

INSERT INTO public.instance_type (type, description)
VALUES ('ZOOKEEPER', 'Zookeeper instance type'),
       ('MYSQL'    , 'MySQL database type'),
       ('PG'       , 'PostgreSQL database type'),
       ('ORA'      , 'Oracle 12 database type'),
       ('ORACLE'   , 'Oracle 11 database type'),
       ('InfluxDB' , 'InfluxDB instance type');
    
-- VOLUME TYPE     
CREATE TABLE public.volume_type (
  id serial,
  type            varchar(64) UNIQUE NOT NULL,
  description     varchar(1024),
  CONSTRAINT volume_type_pkey PRIMARY KEY (id)
);

INSERT INTO public.volume_type (type, description)
VALUES ('NETAPP', 'NETAPP volume type'),
       ('CEPTH' , 'CEPTH volume type');

------------------------------
-- CREATION OF TABLES
------------------------------

-- CLUSTER
CREATE TABLE public.cluster (
    id serial,
    owner varchar(32) NOT NULL,
    name varchar(128) UNIQUE NOT NULL,
    egroup varchar(256),
    category instance_category NOT NULL,
    creation_date date NOT NULL,
    expiry_date date,
    type_id integer NOT NULL,
    project varchar(128),
    description varchar(1024),
    version varchar(128),
    master_id integer,
    state instance_state NOT NULL,
    status instance_status NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT cluster_instance_type_fk FOREIGN KEY (type_id) REFERENCES public.instance_type (id),
    CONSTRAINT cluster_master_fk FOREIGN KEY (master_id) REFERENCES public.cluster (id)
);

--FK INDEXES for CLUSTER table
CREATE INDEX cluster_master_idx ON public.cluster (master_id);
CREATE INDEX cluster_type_idx ON public.cluster (type_id);

CREATE TABLE public.cluster_attribute (
    id serial,
    cluster_id integer NOT NULL,
    name varchar(32) NOT NULL,
    value varchar(250) NOT NULL,
    CONSTRAINT cluster_attribute_pkey PRIMARY KEY (id),
    CONSTRAINT cluster_attribute_cluster_fk FOREIGN KEY (cluster_id) REFERENCES public.cluster (id) ON DELETE CASCADE,
    UNIQUE (cluster_id, name)
);

CREATE INDEX cluster_attribute_cluster_idx ON public.cluster_attribute (cluster_id);

-- COMMAND_DEFINITION
CREATE TABLE public.command_definition (
    command_name varchar(64) NOT NULL,
    type varchar(64) NOT NULL,
    exec varchar(2048),
    PRIMARY KEY (command_name, type)
);

-- HOST
CREATE TABLE public.host (
    id serial,
    name varchar(63) UNIQUE NOT NULL,
    memory integer NOT NULL,
    PRIMARY KEY (id)
);

-- INSTANCE
CREATE TABLE public.instance (
    id serial,
    owner varchar(32) NOT NULL,
    name varchar(128) NOT NULL,
    egroup varchar(256),
    category instance_category NOT NULL,
    creation_date timestamp NOT NULL,
    expiry_date timestamp,
    type_id integer NOT NULL,
    size integer,
    project varchar(128),
    description varchar(1024),
    version varchar(128),
    master_id integer,
    slave_id integer,
    host_id integer,
    state instance_state NOT NULL,
    status instance_status NOT NULL,
    cluster_id integer,
    PRIMARY KEY (id),
    CONSTRAINT instance_host_fk FOREIGN KEY (host_id) REFERENCES public.host (id),
    CONSTRAINT instance_instance_type_fk FOREIGN KEY (type_id) REFERENCES public.instance_type,
    CONSTRAINT instance_master_fk FOREIGN KEY (master_id) REFERENCES public.instance (id),
    CONSTRAINT instance_slave_fk FOREIGN KEY (slave_id) REFERENCES public.instance (id),
    CONSTRAINT instance_cluster_fk FOREIGN KEY (cluster_id) REFERENCES public.cluster (id),
    CONSTRAINT instance_name_key UNIQUE (name)
);

--FK INDEXES for INSTANCE table
CREATE INDEX instance_host_idx      ON public.instance (host_id);
CREATE INDEX instance_master_idx    ON public.instance (master_id);
CREATE INDEX instance_slave_idx     ON public.instance (slave_id);
CREATE INDEX instance_type_idx      ON public.instance (type_id);
CREATE INDEX instance_name_idx      ON public.instance (name);

-- INSTANCE_ATTRIBUTE
CREATE TABLE public.instance_attribute (
    id serial,
    instance_id integer NOT NULL,
    name varchar(32) NOT NULL,
    value varchar(250) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT instance_attribute_instance_fk FOREIGN KEY (instance_id) REFERENCES public.instance (id) ON DELETE CASCADE,
    UNIQUE (instance_id, name)
);

-- INSTANCE_CHANGE
CREATE TABLE public.instance_change (
    id serial,
    instance_id integer NOT NULL,
    attribute varchar(32) NOT NULL,
    change_date timestamp NOT NULL,
    requester varchar(32) NOT NULL,
    old_value varchar(1024),
    new_value varchar(1024),
    PRIMARY KEY (id),
    CONSTRAINT instance_change_instance_fk FOREIGN KEY (instance_id) REFERENCES public.instance (id) ON DELETE CASCADE
);

-- JOB
CREATE TABLE public.job (
    id serial,
    instance_id int NOT NULL,
    command_name varchar(64) NOT NULL,
    creation_date timestamp NOT NULL,
    completion_date timestamp,
    requester varchar(32) NOT NULL,
    admin_action int NOT NULL,
    state varchar(32) NOT NULL,
    email_sent timestamp,
    PRIMARY KEY (id),
    CONSTRAINT job_instance_fk FOREIGN KEY (instance_id) REFERENCES public.instance (id) ON DELETE CASCADE
);

-- COMMAND_PARAM
CREATE TABLE public.command_param (
    id serial,
    job_id integer NOT NULL,
    name varchar(64) NOT NULL,
    value text,
    PRIMARY KEY (id),
    CONSTRAINT command_param_job_fk FOREIGN KEY (job_id) REFERENCES public.job (id) ON DELETE CASCADE
);

-- UPGRADE
CREATE TABLE public.upgrade (
    db_type varchar(32) NOT NULL,
    category varchar(32) NOT NULL,
    version_from varchar(128) NOT NULL,
    version_to varchar(128) NOT NULL,
    PRIMARY KEY (db_type, category, version_from)
);

-- FIM_DATA
CREATE TABLE public.fim_data (
    internal_id varchar(36) NOT NULL,
    instance_name varchar(64),
    description varchar(450),
    owner_account_type varchar(20),
    owner_first_name varchar(24),
    owner_last_name varchar(40),
    owner_login varchar(64),
    owner_mail varchar(128),
    owner_phone1 varchar(5),
    owner_phone2 varchar(5),
    owner_portable_phone varchar(7),
    owner_department varchar(3),
    owner_group varchar(3),
    owner_section varchar(3)
);

-- VOLUME
CREATE TABLE public.volume (
    id serial,
    instance_id integer NOT NULL,
    file_mode char(4) NOT NULL,
    owner varchar(32) NOT NULL,
    "group" varchar(32) NOT NULL,
    server varchar(63) NOT NULL,
    mount_options varchar(256) NOT NULL,
    mounting_path varchar(256) NOT NULL,
    type_id integer,
    PRIMARY KEY (id),
    CONSTRAINT volume_instance_fk FOREIGN KEY (instance_id) REFERENCES public.instance (id) ON DELETE CASCADE,
    CONSTRAINT volume_volume_type_fk FOREIGN KEY (type_id) REFERENCES public.volume_type
);

-- VOLUME ATTRIBUTE
CREATE TABLE public.volume_attribute (
    id serial,
    volume_id integer NOT NULL,
    name varchar(32) NOT NULL,
    value varchar(250) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT volume_attribute_volume_fk FOREIGN KEY (volume_id) REFERENCES public.volume (id) ON DELETE CASCADE,
    UNIQUE (volume_id, name)
);

CREATE INDEX volume_attribute_volume_idx ON public.volume_attribute (id);

-- FUNCTIONAL ALIASES
CREATE TABLE public.functional_aliases (
    dns_name varchar(256) NOT NULL,
    db_name varchar(8) UNIQUE,
    alias varchar(256),
    PRIMARY KEY (dns_name)
);

