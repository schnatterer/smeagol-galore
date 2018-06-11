/*
 * Licensed to Jasig under one or more contributor license
 * agreements. See the NOTICE file distributed with this work
 * for additional information regarding copyright ownership.
 * Jasig licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file
 * except in compliance with the License.  You may obtain a
 * copy of the License at the following location:
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
package de.triology.cas.clearpass;


import java.util.HashMap;
import java.util.Map;

import org.jasig.cas.authentication.Authentication;
import org.jasig.cas.monitor.TicketRegistryState;
import org.jasig.cas.ticket.Ticket;
import org.jasig.cas.ticket.TicketGrantingTicket;
import org.jasig.cas.ticket.registry.TicketRegistry;
import org.jasig.cas.authentication.principal.Principal;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Answers;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.runners.MockitoJUnitRunner;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

@RunWith(MockitoJUnitRunner.class)
public class TicketRegistryDecoratorTest {

    @Mock
    private TicketRegistry registry;
    @Mock
    private Ticket ticket;
    @Mock
    private TicketGrantingTicket tgt;

    private TicketRegistryDecorator decorator;
    private Map<String, String> cache;

    @Before
    public void setupObjectUnderTest() {
        cache = new HashMap<>();
        decorator = new TicketRegistryDecorator(registry, cache);
    }

    @Test
    public void getTicket() {
        when(registry.getTicket("Ticket-123")).thenReturn(ticket);
        assertEquals(ticket, decorator.getTicket("Ticket-123"));
    }

    @Test
    public void addTicketWithTGT() {
        when(tgt.getId()).thenReturn("TGT-123");
        Authentication authentication = mock(Authentication.class);
        Principal principal = mock(Principal.class);
        when(authentication.getPrincipal()).thenReturn(principal);
        when(principal.getId()).thenReturn("username");
        when(tgt.getAuthentication()).thenReturn(authentication);
        decorator.addTicket(tgt);
        verify(registry).addTicket(tgt);
        assertEquals("username", cache.get("TGT-123"));
    }

    @Test
    public void addTicketWithNonTGT() {
        decorator.addTicket(ticket);
        verify(registry).addTicket(ticket);
    }

    @Test
    public void deleteTicketWithUser() {
        String ticket = "Ticket-123";
        cache.put(ticket, "username");
        cache.put("username", "password");
        when(registry.deleteTicket(ticket)).thenReturn(true);
        decorator.deleteTicket(ticket);
        assertEquals(1, cache.size());
        verify(registry).deleteTicket(ticket);
    }

    @Test
    public void deleteTicketWithoutUser() {
        String ticket = "Ticket-123";
        cache.put(ticket, "username");
        when(registry.deleteTicket(ticket)).thenReturn(true);
        decorator.deleteTicket(ticket);
        assertEquals(0, cache.size());
        verify(registry).deleteTicket(ticket);
    }

    @Test
    public void getTickets() {
        decorator.getTickets();
        verify(registry).getTickets();
    }

    @Test
    public void sessionCount() {
        assertEquals(Integer.MIN_VALUE, decorator.sessionCount());
    }

    @Test
    public void sessionCountWithTicketRegistryState() {
        TicketRegistry registryState = Mockito.mock(TicketRegistry.class, withSettings().extraInterfaces(TicketRegistryState.class));
        when(((TicketRegistryState)registryState).sessionCount()).thenReturn(123);
        decorator = new TicketRegistryDecorator(registryState, cache);
        assertEquals(123, decorator.sessionCount());
    }

    @Test
    public void serviceTicketCount() {
        assertEquals(Integer.MIN_VALUE, decorator.serviceTicketCount());
    }

    @Test
    public void serviceTicketCountWithTicketRegistryState() {
        TicketRegistry registryState = Mockito.mock(TicketRegistry.class, withSettings().extraInterfaces(TicketRegistryState.class));
        when(((TicketRegistryState)registryState).serviceTicketCount()).thenReturn(123);
        decorator = new TicketRegistryDecorator(registryState, cache);
        assertEquals(123, decorator.serviceTicketCount());
    }
}