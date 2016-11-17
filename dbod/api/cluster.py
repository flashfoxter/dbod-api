#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright (C) 2015, CERN
# This software is distributed under the terms of the GNU General Public
# Licence version 3 (GPL Version 3), copied verbatim in the file "LICENSE".
# In applying this license, CERN does not waive the privileges and immunities
# granted to it by virtue of its status as Intergovernmental Organization
# or submit itself to any jurisdiction.

"""
cluster module, which includes all the classes related with cluster endpoints.
"""

import tornado.web
import logging
import requests
import json

from dbod.api.base import *
from dbod.config import config

class Cluster(tornado.web.RequestHandler):
    """
    This is the handler of **/cluster/<class>/<name>** endpoint.

    This endpoint takes 1 arguments:

    * *<name>* - the name of a *cluster*

    Things that are given for the development of this endpoint:

    * We request indirectly a `Postgres <https://www.postgresql.org/>`_ database through `PostgREST <http://postgrest.com/>`_ which returns a response in JSON format
    * The database's table/view that is used for this endpoint is called *cluster* and provides metadata about a cluster and its instances.
    * Here is an example of this table:

    --ToDO

    The request method implemented for this endpoint is just the :func:`get`.

    """
    def get(self, **args):
        """Returns the metadata of a host or an instance
        The *GET* method returns the instance(s)' metadata given the *host* or the *database name*.
        (No any special headers for this request)

        :param name: the database name which is given in the url
        :type name: str
        :rtype: json - the response of the request
        :raises: HTTPError - when the given cluster name does not exist or in case of an internal error

        """
        name = args.get('name')
        if name:
            composed_url = config.get('postgrest', 'cluster_url') + '?name=eq.' + name
            logging.info('Requesting ' + composed_url)
            response = requests.get(composed_url, verify=False)
            data = response.json()
            if response.ok and data:
                logging.debug("response: " + json.dumps(data))
                self.write({'response' : data})
            elif response.ok:
                logging.warning("Instance metadata not found: " + name)
                raise tornado.web.HTTPError(NOT_FOUND)
            else:
                logging.error("Error fetching instance metadata: " + response.text)
                raise tornado.web.HTTPError(response.status_code)
        else:
            logging.error("Unsupported endpoint")
            raise tornado.web.HTTPError(BAD_REQUEST)



    @http_basic_auth
    def post(self, name):
        """
        The *POST* method inserts a new cluster into the database with all the
        information that is needed for the creation of it.

        In the request body we specify all the information of the *cluster*
        table along with the *attribute* table. We extract and
        separate the information of each table.

        .. note::


            * It's possible to insert more than one *attribute* in one cluster.
            * The cluster names have to be unique
            * If any of the 2 insertions (in *cluster*, *attribute* table) is not successful then an *Exception* is raised and the private function :func:`__delete_cluster__` is used in order to delete what may has been created.
            * Also, the creation is not successful

                * if the client is not authorized or
                * if there is any internal error
                * if the format of the request body is not right or if there is no *database name* field

        :param name: the new cluster name which is given in the url or any other string
        :type name: str
        :raises: HTTPError - in case of an internal error
        :request body:  json

                       - for *instance*: json
                       - for *attribute*: json

        """
        logging.debug(self.request.body)
        cluster = json.loads(self.request.body)

        attributes = None
        entid = None
        # Get the attributes
        if "attributes" in cluster:
            attributes = cluster["attributes"]
            del cluster["attributes"]

        # Insert the instance in database using PostREST
        response = requests.post(config.get('postgrest', 'cluster_url'), json=cluster, headers={'Prefer': 'return=representation'})
        if response.ok:
            clusterid = json.loads(response.text)["id"]
            logging.info("Created instance " + cluster["name"])
            logging.debug(response.text)
            self.set_status(CREATED)
        else:
            logging.error("Error creating the instance: " + response.text)
            raise tornado.web.HTTPError(response.status_code)


        # Insert the attributes
        if attributes:
            insert_attributes = []
            for attribute in attributes:
                insert_attr = {'instance_id': clusterid, 'name': attribute, 'value': attributes[attribute]}
                logging.debug("Inserting attribute: " + json.dumps(insert_attr))
                insert_attributes.append(insert_attr)

            response = requests.post(config.get('postgrest', 'cluster_attribute_url'), json=insert_attributes)
            if response.ok:
                self.set_status(CREATED)
            else:
                logging.error("Error inserting attributes: " + response.text)
                self.__delete_instance__(entid)
                raise tornado.web.HTTPError(response.status_code)



    @http_basic_auth
    def put(self, name):
        """
        The *PUT* method updates a cluster with all the information that is needed.

        In the request body we specify all the information of the *cluster*
        table along with the *attribute* tables.

        The procedure of this method is the following:

        * We extract and separate the information of each table.
        * We get the *id* of the row from the given (unique) database from the url.
        * If it exists, we delete if any information with that *id* exists in the tables.
        * After that, we insert the information to the related table along with the instance *id*.
        * In case of more than one attributes we insert each one separetely.
        * Finally, we update the *cluster* table's row (which include the given database name) with the new given information.

        :param name: the cluster name which is given in the url
        :type name: str
        :raises: HTTPError - when the *request body* format is not right or in case of internall error

        """
        logging.debug(self.request.body)
        instance = json.loads(self.request.body)
        clusterid = self.__get_cluster_id__(name)
        if not clusterid:
            logging.error("Cluster '" + name + "' doest not exist.")
            raise tornado.web.HTTPError(NOT_FOUND)

        # Check if the attributes are changed
        if "attributes" in instance:
            attributes = instance["attributes"]
            response = requests.delete(config.get('postgrest', 'cluster_attribute_url') + "?cluster_id=eq." + str(clusterid))
            if response.ok or response.status_code == 404:
                if len(attributes) > 0:
                    # Insert the attributes
                    insert_attributes = []
                    for attribute in attributes:
                        insert_attr = {'cluster_id': clusterid, 'name': attribute, 'value': attributes[attribute]}
                        logging.debug("Inserting attribute: " + json.dumps(insert_attr))
                        insert_attributes.append(insert_attr)

                    response = requests.post(config.get('postgrest', 'cluster_attribute_url'), json=insert_attributes)
                    if response.ok:
                        self.set_status(NO_CONTENT)
                    else:
                        logging.error("Error inserting attributes: " + response.text)
                        raise tornado.web.HTTPError(response.status_code)
            else:
                logging.error("Error deleting attributes: " + response.text)
                raise tornado.web.HTTPError(response.status_code)
            del instance["attributes"]

    @http_basic_auth
    def delete(self, name):
        """
        The *DELETE* method deletes a cluster by *name*.

        In order to delete a cluster we have to delete all the related information of the specified database name in *cluster*, *attribute* and *instance* tables.

        :param name: the database name which is given in the url
        :type name: str
        :raises: HTTPError - when the given database name cannot be found

        """
        clusterid = self.__get_instance_id__(name)
        if clusterid:
            requests.delete(config.get('postgrest', 'cluster_url') + "?name=eq." + str(name))
        else:
            logging.error("Cluster not found: " + name)
            raise tornado.web.HTTPError(NOT_FOUND)



    def __get_cluster_id__(self, name):
        """
        This is a private function which is used by :func:`put` and :func:`delete` methods.
        Returns the instance *id* given the cluster name in order to be able to operate on the instance related tables. It returns *None* if the specified database name does not exist in the *cluster* table or in case of internal error.

        :param name: the cluster name from which we want to get the *id*
        :type name: str
        :rtype: str or None

        """
        response = requests.get(config.get('postgrest', 'cluster_url') + "?name=eq." + name)
        if response.ok:
            data = response.json()
            if data:
                return data[0]["id"]
            else:
                return None
        else:
            return None