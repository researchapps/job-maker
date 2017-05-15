// Input data
var machines = "data/machines.json"

var cluster = new Vue({

    el: '#main',

    created: function () {
        this.fetchData()
    },

    data: {
        machines: null,
        cluster_name: '',
        script_name: '',
        job_name: '',
        email_address: '',
        time_minutes:0,
        time_hours:0,
        time_seconds:0,
        partition_name:'',
        number_nodes:1
    },

    // Functions we will be using.
    methods: {

        generateScript: function(){
            console.log('hello!')
        },

        fetchData: function () {
            var xhr = new XMLHttpRequest()
            var self = this
            xhr.open('GET', machines)
            xhr.onload = function () {
                self.machines = JSON.parse(xhr.responseText)
                console.log(self.machines)
            }
            xhr.send()
        }
    }


})

var nav = new Vue({

    el: '#nav',

    data: {
        active: 'generate'
    },

    // Functions we will be using.
    methods: {

        makeActive: function(item){
            this.active = item;
        }
    }

})
