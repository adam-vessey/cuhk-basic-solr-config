<?xml version="1.0" encoding="UTF-8"?>
<!-- RELS-EXT -->
<xsl:stylesheet version="1.0"
    xmlns:java="http://xml.apache.org/xalan/java"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:foxml="info:fedora/fedora-system:def/foxml#"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
    xmlns:islandora-rels-ext="http://islandora.ca/ontology/relsext#" exclude-result-prefixes="rdf java">

    <xsl:variable name="single_valued_hashset_for_rels_ext" select="java:java.util.HashSet.new()"/>
    
    <xsl:template match="foxml:datastream[@ID='RELS-EXT']/foxml:datastreamVersion[last()]" name="index_RELS-EXT">
        <xsl:param name="content"/>
        <xsl:param name="prefix">RELS_EXT_</xsl:param>
        <xsl:param name="suffix">_ms</xsl:param>

        <!-- Clearing hash in case the template is ran more than once. -->
        <xsl:variable name="return_from_clear" select="java:clear($single_valued_hashset_for_rels_ext)"/>
        <!-- Load Collection name into new field and index in solr -->
        <xsl:for-each select="$content//rdf:Description/*[@rdf:resource]">
            <xsl:if test="local-name()='isMemberOfCollection'">
                <xsl:variable name="collectionPID" select="substring-after(@rdf:resource,'info:fedora/')"/>
                <xsl:variable name="collectionContent" select="document(concat('http://',$FEDORAUSER,':',$FEDORAPASS,'@',$HOST,':8080/fedora/objects/', $collectionPID, '/datastreams/', 'DC', '/content'))"/>
               
                <field name="collection_membership_pid_ms">
                  <xsl:value-of select="$collectionPID"/>
                </field>
                
                <xsl:for-each select="$collectionContent">
                    <xsl:variable name="tempData" select="substring-after(.,'  ')"/>
                    <xsl:variable name="collectionName" select="substring-before($tempData,'  ')"/>
                    <field name="collection_membership_title_mt">
                        <xsl:value-of select="normalize-space($collectionName)"/>
                    </field>
                    <field name="collection_membership_title_ms">
                        <xsl:value-of select="normalize-space($collectionName)"/>
                    </field>
                </xsl:for-each>
            </xsl:if>
        </xsl:for-each>
        <xsl:apply-templates select="$content//rdf:Description/* | $content//rdf:description/*" mode="rels_ext_element">
          <xsl:with-param name="prefix" select="$prefix"/>
          <xsl:with-param name="suffix" select="$suffix"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- Match elements, call underlying template. -->
    <xsl:template match="*[@rdf:resource]" mode="rels_ext_element">
      <xsl:param name="prefix"/>
      <xsl:param name="suffix"/>

      <xsl:call-template name="rels_ext_fields">
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="type">uri</xsl:with-param>
        <xsl:with-param name="value" select="@rdf:resource"/>
      </xsl:call-template>
    </xsl:template>
    <xsl:template match="*[normalize-space(.)]" mode="rels_ext_element">
      <xsl:param name="prefix"/>
      <xsl:param name="suffix"/>
      <!-- XXX: Parameters as passed in are strings... Let's deal with it as a
        string here, for convenience. -->
      <xsl:if test="string($index_compound_sequence) = 'true' or (string($index_compound_sequence) = 'false' and not(self::islandora-rels-ext:* and starts-with(local-name(), 'isSequenceNumberOf')))">
        <xsl:call-template name="rels_ext_fields">
          <xsl:with-param name="prefix" select="$prefix"/>
          <xsl:with-param name="suffix" select="$suffix"/>
          <xsl:with-param name="type">literal</xsl:with-param>
          <xsl:with-param name="value" select="text()"/>
        </xsl:call-template>
      </xsl:template>
    </xsl:if>

    <!-- Fork between fields without and with the namespace URI in the field
      name. -->
    <xsl:template name="rels_ext_fields">
      <xsl:param name="prefix"/>
      <xsl:param name="suffix"/>
      <xsl:param name="type"/>
      <xsl:param name="value"/>

      <xsl:call-template name="rels_ext_field">
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="type" select="$type"/>
        <xsl:with-param name="value" select="$value"/>
      </xsl:call-template>
      <xsl:call-template name="rels_ext_field">
        <xsl:with-param name="prefix" select="concat($prefix, namespace-uri())"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="type" select="$type"/>
        <xsl:with-param name="value" select="$value"/>
      </xsl:call-template>
    </xsl:template>

    <!-- Actually create a field. -->
    <xsl:template name="rels_ext_field">
      <xsl:param name="prefix"/>
      <xsl:param name="suffix"/>
      <xsl:param name="type"/>
      <xsl:param name="value"/>

      <!-- Prevent multiple generating multiple instances of single-valued fields
      by tracking things in a HashSet -->
      <!-- The method java.util.HashSet.add will return false when the value is
      already in the set. -->
      <xsl:choose>
        <xsl:when
          test="java:add($single_valued_hashset_for_rels_ext, concat($prefix, local-name(), '_', $type, '_s'))">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, local-name(), '_', $type, '_s')"/>
            </xsl:attribute>
            <xsl:value-of select="$value"/>
          </field>
          <xsl:if test="@rdf:datatype = 'http://www.w3.org/2001/XMLSchema#int'">
            <field>
              <xsl:attribute name="name">
                <xsl:value-of select="concat($prefix, local-name(), '_', $type, '_l')"/>
              </xsl:attribute>
              <xsl:value-of select="$value"/>
            </field>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise>
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, local-name(), '_', $type, $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$value"/>
          </field>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>
</xsl:stylesheet>
