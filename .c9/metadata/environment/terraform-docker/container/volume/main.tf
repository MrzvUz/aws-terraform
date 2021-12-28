{"filter":false,"title":"main.tf","tooltip":"/terraform-docker/container/volume/main.tf","undoManager":{"mark":12,"position":12,"stack":[[{"start":{"row":0,"column":0},"end":{"row":19,"column":1},"action":"insert","lines":["resource \"docker_volume\" \"container_volume\" {","  count = length(var.volumes_in)","  name  = \"${var.name_in}-${count.index}-volume\"","","  lifecycle {","    prevent_destroy = false","  }","","  provisioner \"local-exec\" {","    when       = destroy","    command    = \"mkdir ${path.cwd}/../backup/\"","    on_failure = continue","  }","","  provisioner \"local-exec\" {","    when       = destroy","    command    = \"sudo tar -czvf ${path.cwd}/../backup/${self.name}.tar.gz ${self.mountpoint}/\"","    on_failure = fail","  }","}"],"id":1}],[{"start":{"row":1,"column":10},"end":{"row":1,"column":32},"action":"remove","lines":["length(var.volumes_in)"],"id":3},{"start":{"row":1,"column":10},"end":{"row":1,"column":11},"action":"insert","lines":["v"]},{"start":{"row":1,"column":11},"end":{"row":1,"column":12},"action":"insert","lines":["a"]},{"start":{"row":1,"column":12},"end":{"row":1,"column":13},"action":"insert","lines":["r"]},{"start":{"row":1,"column":13},"end":{"row":1,"column":14},"action":"insert","lines":["."]},{"start":{"row":1,"column":14},"end":{"row":1,"column":15},"action":"insert","lines":["v"]}],[{"start":{"row":1,"column":15},"end":{"row":1,"column":16},"action":"insert","lines":["o"],"id":4},{"start":{"row":1,"column":16},"end":{"row":1,"column":17},"action":"insert","lines":["l"]},{"start":{"row":1,"column":17},"end":{"row":1,"column":18},"action":"insert","lines":["u"]}],[{"start":{"row":1,"column":14},"end":{"row":1,"column":18},"action":"remove","lines":["volu"],"id":5},{"start":{"row":1,"column":14},"end":{"row":1,"column":20},"action":"insert","lines":["volume"]}],[{"start":{"row":1,"column":20},"end":{"row":1,"column":21},"action":"insert","lines":["_"],"id":6},{"start":{"row":1,"column":21},"end":{"row":1,"column":22},"action":"insert","lines":["c"]},{"start":{"row":1,"column":22},"end":{"row":1,"column":23},"action":"insert","lines":["o"]}],[{"start":{"row":1,"column":14},"end":{"row":1,"column":23},"action":"remove","lines":["volume_co"],"id":7},{"start":{"row":1,"column":14},"end":{"row":1,"column":26},"action":"insert","lines":["volume_count"]}],[{"start":{"row":2,"column":23},"end":{"row":2,"column":24},"action":"remove","lines":["n"],"id":8},{"start":{"row":2,"column":22},"end":{"row":2,"column":23},"action":"remove","lines":["i"]},{"start":{"row":2,"column":21},"end":{"row":2,"column":22},"action":"remove","lines":["_"]},{"start":{"row":2,"column":20},"end":{"row":2,"column":21},"action":"remove","lines":["e"]},{"start":{"row":2,"column":19},"end":{"row":2,"column":20},"action":"remove","lines":["m"]},{"start":{"row":2,"column":18},"end":{"row":2,"column":19},"action":"remove","lines":["a"]},{"start":{"row":2,"column":17},"end":{"row":2,"column":18},"action":"remove","lines":["n"]}],[{"start":{"row":2,"column":17},"end":{"row":2,"column":18},"action":"insert","lines":["v"],"id":9},{"start":{"row":2,"column":18},"end":{"row":2,"column":19},"action":"insert","lines":["o"]},{"start":{"row":2,"column":19},"end":{"row":2,"column":20},"action":"insert","lines":["l"]}],[{"start":{"row":2,"column":20},"end":{"row":2,"column":21},"action":"insert","lines":["e"],"id":10}],[{"start":{"row":2,"column":20},"end":{"row":2,"column":21},"action":"remove","lines":["e"],"id":11}],[{"start":{"row":2,"column":20},"end":{"row":2,"column":21},"action":"insert","lines":["u"],"id":12}],[{"start":{"row":2,"column":17},"end":{"row":2,"column":21},"action":"remove","lines":["volu"],"id":13},{"start":{"row":2,"column":17},"end":{"row":2,"column":28},"action":"insert","lines":["volume_name"]}],[{"start":{"row":2,"column":50},"end":{"row":2,"column":51},"action":"remove","lines":["e"],"id":14},{"start":{"row":2,"column":49},"end":{"row":2,"column":50},"action":"remove","lines":["m"]},{"start":{"row":2,"column":48},"end":{"row":2,"column":49},"action":"remove","lines":["u"]},{"start":{"row":2,"column":47},"end":{"row":2,"column":48},"action":"remove","lines":["l"]},{"start":{"row":2,"column":46},"end":{"row":2,"column":47},"action":"remove","lines":["o"]},{"start":{"row":2,"column":45},"end":{"row":2,"column":46},"action":"remove","lines":["v"]},{"start":{"row":2,"column":44},"end":{"row":2,"column":45},"action":"remove","lines":["-"]}]]},"ace":{"folds":[],"scrolltop":0,"scrollleft":0,"selection":{"start":{"row":15,"column":18},"end":{"row":15,"column":18},"isBackwards":false},"options":{"guessTabSize":true,"useWrapMode":false,"wrapToView":true},"firstLineState":0},"timestamp":1640662933232,"hash":"d38c842cf369810adb0f1a54a681f0c7f9164c86"}