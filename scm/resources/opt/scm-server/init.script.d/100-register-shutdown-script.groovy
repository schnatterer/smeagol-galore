// this script configures the jenkins plugin

import sonia.scm.script.domain.*;

def findClass(clazzAsString) {
	return Class.forName(clazzAsString, true, Thread.currentThread().getContextClassLoader())
}

try {
	def scriptRepo = injector.getInstance(findClass("sonia.scm.script.domain.StorableScriptRepository"));

	if (scriptRepo.findAll().find { it.title.get().equals("shutdown") } == null) {
		def script = new StorableScript("Groovy", "System.exit(42);")
		script.setTitle("shutdown");
		script.setDescription("DO NOT MODIFY THIS!\n\nThis script ensures a restart whenever the internal function fails.")
		script.setListeners([new Listener(sonia.scm.lifecycle.RestartEvent.class, false)]);
		scriptRepo.store(script);
	}
} catch( ClassNotFoundException e ) {
	println "script plugin seems not to be installed";
}
