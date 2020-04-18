// this script installs required plugins for scm-manager

import sonia.scm.plugin.PluginManager;
import groovy.json.JsonSlurper;

// configuration
def jsonSlurper = new JsonSlurper()
def pluginConfig = jsonSlurper.parseText(new File("/etc/scm/plugin-config.json").text)
def defaultPlugins = pluginConfig.plugins

def plugins = [];

// methods

def isInstalled(installed, name){
   for (def plugin : installed){
       if (plugin.descriptor.information.name.equals(name)){
           return true;
       }
   }
   return false;
}

def getAvailablePlugin(available, name){
   for (def plugin : available){
       if (plugin.descriptor.information.name.equals(name)){
           return plugin.descriptor.information;
       }
   }
   return null;
}

def isFirstStart() {
    def defaultPluginsInstalledFlag = new File(sonia.scm.SCMContext.getContext().getBaseDirectory(), ".defaultPluginsInstalled");
    return defaultPluginsInstalledFlag.createNewFile();
}

// action

// Smeagol
plugins.add("scm-webhook-plugin")
plugins.add("scm-rest-legacy-plugin")

if (isFirstStart()) {
    System.out.println("First start detected; installing default plugins.");
    plugins.addAll(defaultPlugins)
}

def pluginManager = injector.getInstance(PluginManager.class);
def available = pluginManager.getAvailable();
def installed = pluginManager.getInstalled();

def restart = false;
for (def name : plugins) {
    if (!isInstalled(installed, name)){
        def availableInformation = getAvailablePlugin(available, name);
        if (availableInformation == null) {
            System.out.println("Cannot install missing plugin ${name}. No available plugin found!");
        } else {
            System.out.println("install missing plugin ${availableInformation.name} in version ${availableInformation.version}");
            pluginManager.install(name, false);
            restart = true;
        }
    } else {
        System.out.println("plugin ${name} already installed.");
    }
}

if (restart){
    System.out.println("restarting scm-manager");
    pluginManager.executePendingAndRestart();
} else {
    System.out.println("no new plugins installed");
}
