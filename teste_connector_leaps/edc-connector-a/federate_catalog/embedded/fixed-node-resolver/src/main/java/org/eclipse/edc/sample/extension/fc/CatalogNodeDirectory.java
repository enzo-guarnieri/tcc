/*
 *  Copyright (c) 2024 Fraunhofer-Gesellschaft
 *
 *  This program and the accompanying materials are made available under the
 *  terms of the Apache License, Version 2.0 which is available at
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  Contributors:
 *       Fraunhofer-Gesellschaft - initial API and implementation
 *
 */

package org.eclipse.edc.sample.extension.fc;

import org.eclipse.edc.crawler.spi.TargetNode;
import org.eclipse.edc.crawler.spi.TargetNodeDirectory;

import java.util.List;

public class CatalogNodeDirectory implements TargetNodeDirectory {

    @Override
    public List<TargetNode> getAll() {
        var provider1 = new TargetNode(
                "https://w3id.org/edc/v0.0.1/ns/",
                "provider1",
                "http://provider1:19194/protocol",
                List.of("dataspace-protocol-http")
        );

        var provider2 = new TargetNode(
                "https://w3id.org/edc/v0.0.1/ns/",
                "provider2",
                "http://provider2:19194/protocol",
                List.of("dataspace-protocol-http")
        );

        return List.of(provider1, provider2);
    }

    @Override
    public void insert(TargetNode targetNode) {

    }

    @Override
    public TargetNode remove(String s) {
        return null;
    }
}
